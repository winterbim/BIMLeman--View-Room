import { expect, test } from "bun:test";
import { computers, computersForRoom, type Computer, type FeatureAction } from "@bimleman/domain";
import { ClassroomController } from "./controller";
import { MockVeyonAdapter } from "./mock-veyon-adapter";
import { VeyonWindowsAdapter } from "./veyon-windows-adapter";
import type { VeyonTransport } from "./types";

const byHost = (hostname: string): Computer => {
  const computer = computers.find((item) => item.hostname === hostname);
  if (!computer) throw new Error(hostname);
  return computer;
};

test("mock park exposes 24 computers in three rooms", async () => {
  const adapter = new MockVeyonAdapter();
  const states = await Promise.all(computers.map((computer) => adapter.probe(computer)));
  expect(states).toHaveLength(24);
  expect(states.filter((state) => state === "offline")).toHaveLength(3);
  expect(states.filter((state) => state === "error")).toHaveLength(1);
  expect(states.filter((state) => state === "online")).toHaveLength(20);
  for (const roomId of ["room-a", "room-b", "room-c"]) {
    expect(computersForRoom(roomId)).toHaveLength(8);
  }
});

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
  const reports = await controller.lock(computersForRoom("room-a")[0] as Computer).then(async (first) => {
    const room = computersForRoom("room-a");
    const batch = await controller.message(room, "Interro dans 5 minutes");
    return [first, ...batch];
  });
  expect(reports.some((report) => report.ok)).toBe(true);
  expect(reports.some((report) => !report.ok)).toBe(true);
});

test("restricted teacher actions are refused and audited", async () => {
  const adapter = new MockVeyonAdapter();
  const controller = new ClassroomController(adapter, {
    actorId: "invite",
    displayName: "Invité",
    authorizedRoomIds: ["room-a"]
  });
  const report = await controller.lock(byHost("SALLE-C-PC01"));
  expect(report.ok).toBe(false);
  expect(report.message).toContain("pas autorisé");
  expect(adapter.stateOf(byHost("SALLE-C-PC01"))).toBe("online");
  expect(controller.audit.at(-1)?.result).toBe("failure");
});

test("thumbnails are ephemeral simulated images", async () => {
  const adapter = new MockVeyonAdapter();
  const online = byHost("SALLE-A-PC01");
  const offline = byHost("SALLE-C-PC08");
  const image = await adapter.thumbnail(online);
  expect(image?.startsWith("data:image/svg+xml")).toBe(true);
  expect(await adapter.thumbnail(offline)).toBeNull();
});

test("windows adapter forwards actions without secrets", async () => {
  const calls: string[] = [];
  const transport: VeyonTransport = {
    async checkHost(host) {
      calls.push(`check:${host}`);
      return host !== "SALLE-A-PC08";
    },
    async openView(host) {
      calls.push(`view:${host}`);
    },
    async openControl(host) {
      calls.push(`control:${host}`);
    },
    async thumbnail(host) {
      calls.push(`thumb:${host}`);
      return "data:image/jpeg;base64,AAAA";
    },
    async feature(host, action: FeatureAction, payload?: string) {
      calls.push(`feature:${host}:${action}:${payload ?? ""}`);
    }
  };
  const adapter = new VeyonWindowsAdapter(transport);
  const computer = byHost("SALLE-A-PC01");
  expect(await adapter.probe(computer)).toBe("online");
  await adapter.view(computer);
  await adapter.control(computer);
  expect(adapter.stateOf(computer)).toBe("controlled");
  await adapter.feature(computer, "lock");
  expect(adapter.stateOf(computer)).toBe("locked");
  await adapter.feature(computer, "message", "Bonjour");
  expect(await adapter.thumbnail(computer)).toContain("data:image/jpeg");
  const serialized = JSON.stringify(calls);
  expect(serialized).not.toContain("PRIVATE");
  expect(serialized).not.toContain("keydata");
  expect(calls).toContain("feature:SALLE-A-PC01:message:Bonjour");
});
