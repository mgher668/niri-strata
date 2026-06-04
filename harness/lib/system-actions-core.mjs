export const sessionActionCommands = {
  lock: ["swaylock", "--screenshots", "--clock", "--indicator"],
  logout: ["niri", "msg", "action", "quit"],
  suspend: ["systemctl", "suspend"],
  reboot: ["systemctl", "reboot"],
  shutdown: ["systemctl", "poweroff"],
};

export function requiresConfirmation(actionId) {
  return ["logout", "suspend", "reboot", "shutdown"].includes(actionId);
}

export function sessionActionCommand(actionId) {
  return sessionActionCommands[actionId] ?? null;
}
