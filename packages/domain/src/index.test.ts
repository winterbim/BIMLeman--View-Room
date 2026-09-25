import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  AccessDeniedError,
  assertAuthorized,
  assertMessage,
  assertWebsite,
  computers,
  computersForRoom,
  ConfirmationRequiredError,
  createAuditEvent,
  defaultTeacher,
  isManagedHostname,
  parseInventory,
  requiresConfirmation,
  rooms
} from "./index";

const inventoryPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../inventory/pc-inventory.csv"
);

test("inventory contains three rooms", () => {
  expect(rooms.map((room) => room.code)).toEqual(["A", "B", "C"]);
});

test("inventory contains exactly 24 computers", () => {
  expect(computers).toHaveLength(24);
  expect(new Set(computers.map((computer) => computer.hostname)).size).toBe(24);
});

test("each room contains eight computers", () => {
  for (const room of rooms) expect(computersForRoom(room.id)).toHaveLength(8);
});

test("hostnames follow the managed park pattern", () => {
  for (const computer of computers) {
    expect(isManagedHostname(computer.hostname)).toBe(true);
    expect(computer.address).toBe(computer.hostname);
  }
  expect(isManagedHostname("SALLE-A-PC09")).toBe(false);
  expect(isManagedHostname("other-pc")).toBe(false);
});

test("csv inventory matches the built-in park", () => {
  const csv = readFileSync(inventoryPath, "utf8");
  const parsed = parseInventory(csv);
  expect(parsed.map((computer) => computer.hostname)).toEqual(computers.map((computer) => computer.hostname));
});

test("default teacher can access every room", () => {
  for (const room of rooms) expect(() => assertAuthorized(defaultTeacher, room.id)).not.toThrow();
});

test("restricted teacher cannot access another room", () => {
  const teacher = { ...defaultTeacher, authorizedRoomIds: ["room-a"] };
  expect(() => assertAuthorized(teacher, "room-c")).toThrow(AccessDeniedError);
});

test("reboot and shutdown require confirmation", () => {
  expect(requiresConfirmation("reboot")).toBe(true);
  expect(requiresConfirmation("shutdown")).toBe(true);
  expect(requiresConfirmation("lock")).toBe(false);
  expect(new ConfirmationRequiredError("shutdown").code).toBe("confirmation");
});

test("message and website inputs are validated", () => {
  expect(assertMessage("  Bonjour la salle  ")).toBe("Bonjour la salle");
  expect(() => assertMessage("   ")).toThrow(/vide/);
  expect(() => assertMessage("x".repeat(501))).toThrow(/500/);
  expect(assertWebsite("https://bimleman.ch/cours")).toBe("https://bimleman.ch/cours");
  expect(() => assertWebsite("javascript:alert(1)")).toThrow(/http/);
  expect(() => assertWebsite("file:///C:/Windows")).toThrow(/http/);
  expect(() => assertWebsite("https://user:secret@example.test")).toThrow(/identifiants/);
});

test("audit event records the action without screen content", () => {
  const event = createAuditEvent({
    actor: "formateur",
    action: "message",
    result: "success",
    computer: computers[0],
    at: "2026-09-25T08:00:00.000Z"
  });
  expect(event).toEqual({
    at: "2026-09-25T08:00:00.000Z",
    actor: "formateur",
    computerId: "A-01",
    roomId: "room-a",
    action: "message",
    result: "success"
  });
  expect(JSON.stringify(event)).not.toContain("data:image");
});
