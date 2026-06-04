.pragma library

const failedSources = {};

function hasFailed(source) {
    return failedSources[String(source ?? "")] === true;
}

function markFailed(source) {
    const key = String(source ?? "");
    if (key.length > 0)
        failedSources[key] = true;
}
