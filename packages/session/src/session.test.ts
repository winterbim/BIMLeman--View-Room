import { expect, test } from "bun:test";
import { computers, computersForRoom, type Computer, type ComputerState, type FeatureAction } from "@bimleman/domain";
import type { ClassroomControlAdapter } from "@bimleman/veyon-adapter";
import { MockVeyonAdapter } from "@bimleman/veyon-adapter";
import { ClassroomController, postconditionMet } from "./controller";

const byHost = (hostname: string): Computer => {
  const computer = computers.find((item) => item.hostname === hostname);
  if (!computer) throw new Error(hostname);
  return computer;
};

test("mock workflows cover view, assist, lock, message, url and power", async () => {
  const controller = new ClassroomController(new MockVeyonAdapter());
  const online = byHost("SALLE-A-PC01");
  const offline = byHost("SALLE-A-PC08");

  expect((await controller.view(online)).ok).toBe(true);
  expect((await controller.control(online)).state).toBe("controlled");
  expect((await controller.lock(online)).state).toBe("locked");
  expect((await controller.unlock(online)).state).toBe("online");

  const secret = "CONSIGNE-SECRETE-NE-PAS-JOURNALISER";
  const message = await controller.message([online], secret);
  expect(message[0]?.ok).toBe(true);
  expect(JSON.stringify(controller.audit)).not.toContain(secret);
  expect(JSON.stringify(controller.audit)).not.toContain("data:image");
  expect(JSON.stringify(controller.audit)).not.toContain("PRIVATE KEY");

  expect((await controller.openWebsite([online], "https://example.test/cours"))[0]?.ok).toBe(true);
  await expect(controller.openWebsite([online], "javascript:alert(1)")).rejects.toThrow(/http/);

  const denied = await controller.lock(offline);
  expect(denied.ok).toBe(false);
  expect(denied.message).toContain("hors ligne");

  await expect(controller.shutdown([online], false)).rejects.toThrow(/Confirmation/);
  expect((await controller.shutdown([online], true))[0]?.state).toBe("offline");
  expect((await controller.reboot([byHost("SALLE-A-PC02")], true))[0]?.state).toBe("offline");
});

test("room batch continues after an unreachable computer", async () => {
  const controller = new ClassroomController(new MockVeyonAdapter());
  const room = computersForRoom("room-a");
  const first = room[0];
  if (!first) throw new Error("salle vide");
  const locked = await controller.lock(first);
  const batch = await controller.message(room, "Interro dans 5 minutes");
  const reports = [locked, ...batch];
  expect(reports.some((report) => report.ok)).toBe(true);
  expect(reports.some((report) => !report.ok)).toBe(true);
});

test("restricted teacher actions are refused and audited", async () => {
  const adapter = new MockVeyonAdapter();
  const rooms = ["room-a"];
  const controller = new ClassroomController(adapter, {
    actorId: "invite",
    displayName: "Invité",
    authorizedRoomIds: rooms
  });
  rooms.push("room-c");
  const report = await controller.lock(byHost("SALLE-C-PC01"));
  expect(report.ok).toBe(false);
  expect(report.message).toContain("pas autorisé");
  expect(adapter.stateOf(byHost("SALLE-C-PC01"))).toBe("online");
  expect(controller.audit.at(-1)?.result).toBe("failure");
});

test("an effect that does not change state is not recorded as success", async () => {
  const adapter: ClassroomControlAdapter = {
    mode: "mock",
    stateOf(): ComputerState { return "online"; },
    async probe(): Promise<ComputerState> { return "online"; },
    async view(): Promise<void> { return; },
    async control(): Promise<void> { return; },
    async feature(_computer: Computer, _action: FeatureAction): Promise<void> { return; },
    async thumbnail(): Promise<string | null> { return null; }
  };
  const controller = new ClassroomController(adapter);
  const report = await controller.lock(byHost("SALLE-A-PC01"));
  expect(report.ok).toBe(false);
  expect(report.message).toContain("état attendu");
  expect(controller.audit.at(-1)?.result).toBe("failure");
  expect(postconditionMet("lock", "online", "online")).toBe(false);
  expect(postconditionMet("lock", "online", "locked")).toBe(true);
  expect(postconditionMet("unknown", "online", "online")).toBe(false);
});
