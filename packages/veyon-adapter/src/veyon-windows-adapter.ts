import { ControlError, isManagedHostname, type Computer, type ComputerState, type FeatureAction } from "@bimleman/domain";
import type { ClassroomControlAdapter, VeyonTransport } from "./types";

const CALL_TIMEOUT_MS = 10_000;

function withTimeout<T>(promise: Promise<T>, label: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new ControlError(`Délai dépassé pendant « ${label} ».`, "timeout"));
    }, CALL_TIMEOUT_MS);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timer);
        reject(error instanceof ControlError ? error : new ControlError(errorText(error), "veyon"));
      }
    );
  });
}

function errorText(error: unknown): string {
  if (error instanceof Error) return error.message;
  return "Erreur Veyon.";
}

export class VeyonWindowsAdapter implements ClassroomControlAdapter {
  readonly mode = "veyon" as const;
  private readonly flags = new Map<string, ComputerState>();

  constructor(private readonly transport: VeyonTransport) {}

  stateOf(computer: Computer): ComputerState {
    return this.flags.get(computer.id) ?? "offline";
  }

  async probe(computer: Computer): Promise<ComputerState> {
    this.assertManaged(computer);
    try {
      const reachable = await withTimeout(this.transport.checkHost(computer.address), "test TCP 11100");
      if (!reachable) {
        this.flags.set(computer.id, "offline");
        return "offline";
      }
      const preserved = this.flags.get(computer.id);
      const next = preserved === "locked" || preserved === "controlled" ? preserved : "online";
      this.flags.set(computer.id, next);
      return next;
    } catch (error) {
      this.flags.set(computer.id, "error");
      if (error instanceof ControlError) throw error;
      throw new ControlError(errorText(error), "veyon");
    }
  }

  async view(computer: Computer): Promise<void> {
    await this.requireOnline(computer);
    await withTimeout(this.transport.openView(computer.address), "voir");
  }

  async control(computer: Computer): Promise<void> {
    await this.requireOnline(computer);
    await withTimeout(this.transport.openControl(computer.address), "aider");
    if (this.flags.get(computer.id) !== "locked") this.flags.set(computer.id, "controlled");
  }

  async feature(computer: Computer, action: FeatureAction, payload?: string): Promise<void> {
    await this.requireOnline(computer);
    await withTimeout(this.transport.feature(computer.address, action, payload), action);
    if (action === "lock") this.flags.set(computer.id, "locked");
    if (action === "unlock" && this.flags.get(computer.id) === "locked") this.flags.set(computer.id, "online");
    if (action === "reboot" || action === "shutdown") this.flags.set(computer.id, "offline");
  }

  async thumbnail(computer: Computer): Promise<string | null> {
    const state = this.stateOf(computer);
    if (state === "offline" || state === "error") return null;
    try {
      return await withTimeout(this.transport.thumbnail(computer.address), "miniature");
    } catch {
      return null;
    }
  }

  private async requireOnline(computer: Computer): Promise<void> {
    this.assertManaged(computer);
    const state = this.flags.get(computer.id);
    if (state === "offline" || state === undefined) {
      throw new ControlError(`${computer.hostname} est hors ligne ou n'a pas encore été testé.`, "unreachable");
    }
    if (state === "error") {
      throw new ControlError(`${computer.hostname} est en erreur réseau.`, "unreachable");
    }
  }

  private assertManaged(computer: Computer): void {
    if (!isManagedHostname(computer.hostname) || !isManagedHostname(computer.address)) {
      throw new ControlError(`${computer.hostname} est hors du parc autorisé.`, "denied");
    }
  }
}
