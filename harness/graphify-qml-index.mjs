#!/usr/bin/env node
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const projectRoot = process.cwd();
const markdownOut = path.join(projectRoot, "docs/generated/qml-graph.md");
const moduleOut = path.join(projectRoot, "harness/generated/qml-graph.mjs");

const ignoredDirectories = new Set([
  ".git",
  ".serena",
  "graphify-out",
  "node_modules",
  "temp",
  "tmp",
]);

const localQtTypes = new Set([
  "Behavior",
  "Column",
  "ColumnLayout",
  "Component",
  "Connections",
  "GridLayout",
  "Item",
  "ListView",
  "Loader",
  "MouseArea",
  "NumberAnimation",
  "PanelWindow",
  "Rectangle",
  "Repeater",
  "Row",
  "RowLayout",
  "Scope",
  "ShellRoot",
  "Text",
  "Timer",
  "Translate",
  "Variants",
]);

function toPosix(relativePath) {
  return relativePath.split(path.sep).join("/");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function functionNameFor(relativePath) {
  const stem = path.basename(relativePath, ".qml");
  const suffix = relativePath
    .replace(/\.qml$/i, "")
    .replace(/[^A-Za-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  const base = /^[A-Za-z_]/.test(stem) ? stem : suffix;
  return `qml_${base.replace(/[^A-Za-z0-9_]/g, "_") || suffix}`;
}

function lineStartsFor(text) {
  const starts = [0];
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === "\n")
      starts.push(index + 1);
  }
  return starts;
}

function lineAt(offset, starts) {
  let low = 0;
  let high = starts.length - 1;
  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (starts[mid] <= offset)
      low = mid + 1;
    else
      high = mid - 1;
  }
  return high + 1;
}

function maskQml(text) {
  let result = "";
  let state = "code";
  let quote = "";
  let escaped = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (state === "lineComment") {
      if (char === "\n") {
        state = "code";
        result += "\n";
      } else {
        result += " ";
      }
      continue;
    }

    if (state === "blockComment") {
      if (char === "*" && next === "/") {
        result += "  ";
        index += 1;
        state = "code";
      } else {
        result += char === "\n" ? "\n" : " ";
      }
      continue;
    }

    if (state === "string") {
      if (escaped) {
        escaped = false;
        result += char === "\n" ? "\n" : " ";
        continue;
      }
      if (char === "\\") {
        escaped = true;
        result += " ";
        continue;
      }
      if (char === quote) {
        state = "code";
        quote = "";
      }
      result += char === "\n" ? "\n" : " ";
      continue;
    }

    if (char === "/" && next === "/") {
      result += "  ";
      index += 1;
      state = "lineComment";
      continue;
    }
    if (char === "/" && next === "*") {
      result += "  ";
      index += 1;
      state = "blockComment";
      continue;
    }
    if (char === "\"" || char === "'" || char === "`") {
      quote = char;
      state = "string";
      result += " ";
      continue;
    }

    result += char;
  }

  return result;
}

function stripLineComment(line) {
  let quote = "";
  let escaped = false;
  for (let index = 0; index < line.length - 1; index += 1) {
    const char = line[index];
    const next = line[index + 1];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (quote) {
      if (char === "\\")
        escaped = true;
      else if (char === quote)
        quote = "";
      continue;
    }
    if (char === "\"" || char === "'") {
      quote = char;
      continue;
    }
    if (char === "/" && next === "/")
      return line.slice(0, index);
  }
  return line;
}

function parseImport(line, lineNumber) {
  const clean = stripLineComment(line).trim();
  if (!clean.startsWith("import "))
    return null;

  const rest = clean.slice("import ".length).trim();
  if (!rest)
    return null;

  const quoted = rest.match(/^["']([^"']+)["'](?:\s+(.+))?$/);
  if (quoted) {
    const tail = quoted[2] ?? "";
    const alias = tail.match(/\bas\s+([A-Za-z_][A-Za-z0-9_]*)\b/)?.[1] ?? "";
    return {
      source: quoted[1],
      alias,
      version: "",
      line: lineNumber,
      kind: quoted[1].startsWith(".") ? "path" : "module",
    };
  }

  const parts = rest.split(/\s+/);
  const source = parts[0];
  let version = "";
  let alias = "";

  for (let index = 1; index < parts.length; index += 1) {
    if (parts[index] === "as" && parts[index + 1]) {
      alias = parts[index + 1];
      break;
    }
    if (/^\d+(?:\.\d+)*$/.test(parts[index]))
      version = parts[index];
  }

  return {
    source,
    alias,
    version,
    line: lineNumber,
    kind: source.startsWith(".") ? "path" : "module",
  };
}

function collectPattern(masked, pattern, starts, mapper) {
  const values = [];
  for (const match of masked.matchAll(pattern)) {
    values.push(mapper(match, lineAt(match.index, starts)));
  }
  return values;
}

function uniqueByName(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const key = item.name;
    if (seen.has(key))
      continue;
    seen.add(key);
    result.push(item);
  }
  return result;
}

function addUniqueRelation(map, name, line, relation) {
  const current = map.get(name);
  if (!current) {
    map.set(name, { name, lines: [line], relations: new Set([relation]) });
    return;
  }
  if (!current.lines.includes(line))
    current.lines.push(line);
  current.relations.add(relation);
}

async function walkQmlFiles(root) {
  const files = [];

  async function walkDirectory(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (ignoredDirectories.has(entry.name))
          continue;
        await walkDirectory(path.join(directory, entry.name));
        continue;
      }

      if (!entry.isFile() || !entry.name.endsWith(".qml"))
        continue;

      files.push(path.join(directory, entry.name));
    }
  }

  await walkDirectory(root);
  return files.sort((left, right) => left.localeCompare(right));
}

function analyzeQml(relativePath, source, componentByName) {
  const masked = maskQml(source);
  const starts = lineStartsFor(masked);
  const lines = source.split(/\r?\n/);
  const imports = [];

  lines.forEach((line, index) => {
    const item = parseImport(line, index + 1);
    if (item)
      imports.push(item);
  });

  const instances = collectPattern(
    masked,
    /(^|[^\w.])([A-Z][A-Za-z0-9_]*)\s*\{/gm,
    starts,
    (match, line) => ({ name: match[2], line }),
  );
  const rootType = instances[0]?.name ?? "";
  const componentName = path.basename(relativePath, ".qml");
  const localRelations = new Map();

  for (const instance of instances) {
    const target = componentByName.get(instance.name);
    if (target && target.relativePath !== relativePath)
      addUniqueRelation(localRelations, instance.name, instance.line, "instantiates");
  }

  for (const name of componentByName.keys()) {
    const target = componentByName.get(name);
    if (!target || target.relativePath === relativePath)
      continue;

    const mentionPattern = new RegExp(`\\b${escapeRegExp(name)}\\b\\s*(?=\\.|\\{|\\()`, "g");
    for (const match of masked.matchAll(mentionPattern)) {
      const line = lineAt(match.index, starts);
      addUniqueRelation(localRelations, name, line, "references");
    }
  }

  const properties = uniqueByName(collectPattern(
    masked,
    /^\s*(?:(?:readonly|required|default|final)\s+)*property\s+(?:alias|[A-Za-z_][A-Za-z0-9_.<>]*)\s+([A-Za-z_][A-Za-z0-9_]*)/gm,
    starts,
    (match, line) => ({ name: match[1], line }),
  ));

  const functions = uniqueByName(collectPattern(
    masked,
    /^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm,
    starts,
    (match, line) => ({ name: match[1], line }),
  ));

  const signals = uniqueByName(collectPattern(
    masked,
    /^\s*signal\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|$)/gm,
    starts,
    (match, line) => ({ name: match[1], line }),
  ));

  const ids = uniqueByName(collectPattern(
    masked,
    /^\s*id\s*:\s*([A-Za-z_][A-Za-z0-9_]*)/gm,
    starts,
    (match, line) => ({ name: match[1], line }),
  ));

  const pragmas = lines
    .map((line, index) => ({ text: line.trim(), line: index + 1 }))
    .filter(item => item.text.startsWith("//@ pragma") || item.text.startsWith("pragma "));

  const qtTypes = uniqueByName(instances.filter(item => localQtTypes.has(item.name)));

  return {
    componentName,
    relativePath,
    functionName: functionNameFor(relativePath),
    rootType,
    imports,
    localRelations: [...localRelations.values()].sort((left, right) => left.name.localeCompare(right.name)),
    properties,
    functions,
    signals,
    ids,
    pragmas,
    qtTypes,
  };
}

function relationLine(item, componentByName) {
  const target = componentByName.get(item.name);
  const relations = [...item.relations].sort().join(", ");
  const lines = item.lines.sort((left, right) => left - right).slice(0, 8).join(", ");
  return `- \`${item.name}\` -> \`${target.relativePath}\` (${relations}; L${lines})`;
}

function detailList(title, items, formatter) {
  if (items.length === 0)
    return [`- ${title}: none`];
  return [
    `- ${title}:`,
    ...items.map(item => `  - ${formatter(item)}`),
  ];
}

function renderMarkdown(analyses, componentByName) {
  const relationCount = analyses.reduce((total, item) => total + item.localRelations.length, 0);
  const importCount = analyses.reduce((total, item) => total + item.imports.length, 0);
  const lines = [
    "# QML Graph Index",
    "",
    "Generated by `npm run graphify:qml`. This file is intentionally structured so graphify can index QML modules even though it does not parse `.qml` directly.",
    "",
    "## Summary",
    "",
    `- QML files: ${analyses.length}`,
    `- Local QML relations: ${relationCount}`,
    `- Imports: ${importCount}`,
    `- Generated graph bridge: \`harness/generated/qml-graph.mjs\``,
    "",
    "## Local QML Dependency Map",
    "",
  ];

  for (const analysis of analyses) {
    lines.push(
      `### ${analysis.componentName}`,
      "",
      `- Path: \`${analysis.relativePath}\``,
      `- Root type: \`${analysis.rootType || "unknown"}\``,
      ...detailList("Imports", analysis.imports, item => {
        const bits = [`\`${item.source}\``];
        if (item.version)
          bits.push(`version \`${item.version}\``);
        if (item.alias)
          bits.push(`as \`${item.alias}\``);
        bits.push(`L${item.line}`);
        return bits.join(" ");
      }),
      ...detailList("Local QML dependencies", analysis.localRelations, item => relationLine(item, componentByName).slice(2)),
      ...detailList("Properties", analysis.properties, item => `\`${item.name}\` L${item.line}`),
      ...detailList("Functions", analysis.functions, item => `\`${item.name}()\` L${item.line}`),
      ...detailList("Signals", analysis.signals, item => `\`${item.name}\` L${item.line}`),
      ...detailList("IDs", analysis.ids, item => `\`${item.name}\` L${item.line}`),
      "",
    );
  }

  lines.push(
    "## Unresolved Built-In Or External Types",
    "",
    "These are common Qt/Quickshell types seen in object declarations and are not linked to project-local QML files.",
    "",
  );
  const qtTypeCounts = new Map();
  for (const analysis of analyses) {
    for (const item of analysis.qtTypes)
      qtTypeCounts.set(item.name, (qtTypeCounts.get(item.name) ?? 0) + 1);
  }
  for (const [name, count] of [...qtTypeCounts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])))
    lines.push(`- \`${name}\`: ${count} files`);

  lines.push("");
  return lines.join("\n");
}

function renderGraphBridge(analyses, componentByName) {
  const lines = [
    "// Generated by harness/graphify-qml-index.mjs. Do not edit by hand.",
    "// This bridge gives graphify's JavaScript AST extractor concrete call edges for QML modules.",
    "",
  ];

  for (const analysis of analyses) {
    lines.push(`export function ${analysis.functionName}() {`);
    lines.push(`  // ${analysis.relativePath}`);
    if (analysis.rootType)
      lines.push(`  const rootType = ${JSON.stringify(analysis.rootType)};`);
    else
      lines.push("  const rootType = \"\";");

    const calls = analysis.localRelations
      .map(item => componentByName.get(item.name))
      .filter(Boolean)
      .map(item => item.functionName)
      .filter(name => name !== analysis.functionName);

    const uniqueCalls = [...new Set(calls)].sort();
    for (const call of uniqueCalls)
      lines.push(`  ${call}();`);
    lines.push("  return rootType;");
    lines.push("}");
    lines.push("");
  }

  lines.push("export const qmlGraphSummary = Object.freeze({");
  lines.push(`  files: ${analyses.length},`);
  lines.push(`  relations: ${analyses.reduce((total, item) => total + item.localRelations.length, 0)},`);
  lines.push("});");
  lines.push("");
  return lines.join("\n");
}

async function main() {
  const qmlFiles = await walkQmlFiles(projectRoot);
  const componentByName = new Map();

  for (const absolutePath of qmlFiles) {
    const relativePath = toPosix(path.relative(projectRoot, absolutePath));
    const componentName = path.basename(relativePath, ".qml");
    if (!componentByName.has(componentName)) {
      componentByName.set(componentName, {
        componentName,
        relativePath,
        functionName: functionNameFor(relativePath),
      });
    }
  }

  const analyses = [];
  for (const absolutePath of qmlFiles) {
    const relativePath = toPosix(path.relative(projectRoot, absolutePath));
    const source = await readFile(absolutePath, "utf8");
    const analysis = analyzeQml(relativePath, source, componentByName);
    const known = componentByName.get(analysis.componentName);
    if (known)
      known.functionName = analysis.functionName;
    analyses.push(analysis);
  }

  await mkdir(path.dirname(markdownOut), { recursive: true });
  await mkdir(path.dirname(moduleOut), { recursive: true });
  await writeFile(markdownOut, renderMarkdown(analyses, componentByName), "utf8");
  await writeFile(moduleOut, renderGraphBridge(analyses, componentByName), "utf8");

  const relationCount = analyses.reduce((total, item) => total + item.localRelations.length, 0);
  console.log(`QML files: ${analyses.length}`);
  console.log(`Local QML relations: ${relationCount}`);
  console.log(`Wrote ${toPosix(path.relative(projectRoot, markdownOut))}`);
  console.log(`Wrote ${toPosix(path.relative(projectRoot, moduleOut))}`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
