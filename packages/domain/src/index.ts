export type RoomCode = "A" | "B" | "C";
export type ComputerState = "online" | "offline" | "locked" | "controlled" | "error";
export type FeatureAction = "lock" | "unlock" | "message" | "openWebsite" | "reboot" | "shutdown";
export type AuditResult = "success" | "failure";

export interface Room {
  id: string;
  code: RoomCode;
  name: string;
}

export interface Computer {
  id: string;
  roomId: string;
  seat: number;
  hostname: string;
  address: string;
}

export interface AuditEvent {
  at: string;
  actor: string;
  computerId?: string;
  roomId?: string;
  action: string;
  result: AuditResult;
}

export interface TeacherProfile {
  actorId: string;
  displayName: string;
  authorizedRoomIds: readonly string[];
}

export type ControlErrorCode =
  | "offline"
  | "timeout"
  | "denied"
  | "unreachable"
  | "confirmation"
  | "invalid"
  | "veyon";

export class ControlError extends Error {
  readonly code: ControlErrorCode;

  constructor(message: string, code: ControlErrorCode) {
    super(message);
    this.name = "ControlError";
    this.code = code;
  }
}

export class AccessDeniedError extends ControlError {
  constructor(message = "Ce formateur n'est pas autorisé sur cette salle.") {
    super(message, "denied");
    this.name = "AccessDeniedError";
  }
}

export class ConfirmationRequiredError extends ControlError {
  constructor(action: FeatureAction) {
    super(`Confirmation requise avant l'action « ${action} ».`, "confirmation");
    this.name = "ConfirmationRequiredError";
  }
}

const ROOM_ORDER: RoomCode[] = ["A", "B", "C"];

export const rooms: Room[] = ROOM_ORDER.map((code) => ({
  id: `room-${code.toLowerCase()}`,
  code,
  name: `Salle ${code}`
}));

export const defaultTeacher: TeacherProfile = {
  actorId: "formateur",
  displayName: "Formateur",
  authorizedRoomIds: rooms.map((room) => room.id)
};

export const computers: Computer[] = rooms.flatMap((room) =>
  Array.from({ length: 8 }, (_, index) => {
    const seat = index + 1;
    const number = String(seat).padStart(2, "0");
    const hostname = `SALLE-${room.code}-PC${number}`;
    return {
      id: `${room.code}-${number}`,
      roomId: room.id,
      seat,
      hostname,
      address: hostname
    };
  })
);

export function computersForRoom(roomId: string): Computer[] {
  return computers.filter((computer) => computer.roomId === roomId);
}

export function roomById(roomId: string): Room | undefined {
  return rooms.find((room) => room.id === roomId);
}

export function isRoomCode(value: string): value is RoomCode {
  return value === "A" || value === "B" || value === "C";
}

export function isManagedHostname(hostname: string): boolean {
  return /^SALLE-[ABC]-PC0[1-8]$/.test(hostname);
}

export function requiresConfirmation(action: FeatureAction): boolean {
  return action === "reboot" || action === "shutdown";
}

export function assertAuthorized(teacher: TeacherProfile, roomId: string): void {
  if (!teacher.authorizedRoomIds.includes(roomId)) {
    const room = roomById(roomId);
    throw new AccessDeniedError(
      `${teacher.displayName} n'est pas autorisé sur ${room?.name ?? roomId}.`
    );
  }
}

export function assertMessage(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) throw new ControlError("Le message est vide.", "invalid");
  if (trimmed.length > 500) throw new ControlError("Le message dépasse 500 caractères.", "invalid");
  return trimmed;
}

export function assertWebsite(value: string): string {
  let parsed: URL;
  try {
    parsed = new URL(value.trim());
  } catch {
    throw new ControlError("Adresse web invalide.", "invalid");
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new ControlError("Seules les adresses http et https sont autorisées.", "invalid");
  }
  if (parsed.username || parsed.password) {
    throw new ControlError("Les identifiants dans l'adresse sont refusés.", "invalid");
  }
  return parsed.toString();
}

export function createAuditEvent(input: {
  actor: string;
  action: string;
  result: AuditResult;
  computer?: Computer;
  at?: string;
}): AuditEvent {
  return {
    at: input.at ?? new Date().toISOString(),
    actor: input.actor,
    computerId: input.computer?.id,
    roomId: input.computer?.roomId,
    action: input.action,
    result: input.result
  };
}

export function parseInventory(csv: string): Computer[] {
  const lines = csv.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const header = lines.shift()?.split(";") ?? [];
  const column = (name: string) => {
    const index = header.indexOf(name);
    if (index < 0) throw new ControlError(`Colonne d'inventaire manquante : ${name}.`, "invalid");
    return index;
  };
  const roomIndex = column("RoomCode");
  const seatIndex = column("Seat");
  const hostnameIndex = column("DesiredHostname");
  const addressIndex = column("HostAddress");
  const parsed = lines.map((line) => {
    const cells = line.split(";");
    const code = cells[roomIndex]?.trim() ?? "";
    const seat = Number(cells[seatIndex]);
    const hostname = cells[hostnameIndex]?.trim() ?? "";
    const address = cells[addressIndex]?.trim() || hostname;
    if (!isRoomCode(code) || !Number.isInteger(seat) || seat < 1 || seat > 8) {
      throw new ControlError(`Ligne d'inventaire invalide : ${line}`, "invalid");
    }
    if (!isManagedHostname(hostname)) {
      throw new ControlError(`Nom de poste hors parc : ${hostname}`, "invalid");
    }
    const room = rooms.find((item) => item.code === code);
    if (!room) throw new ControlError(`Salle inconnue : ${code}`, "invalid");
    return {
      id: `${code}-${String(seat).padStart(2, "0")}`,
      roomId: room.id,
      seat,
      hostname,
      address
    } satisfies Computer;
  });
  if (parsed.length !== 24) {
    throw new ControlError(`L'inventaire doit contenir 24 postes, reçu ${parsed.length}.`, "invalid");
  }
  return parsed;
}
