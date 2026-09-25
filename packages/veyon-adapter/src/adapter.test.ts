import { expect, test } from "bun:test";
import { computers, computersForRoom, type Computer, type FeatureAction } from "@bimleman/domain";
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
