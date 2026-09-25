import {
  assertAuthorized,
  assertMessage,
  assertWebsite,
  ConfirmationRequiredError,
  createAuditEvent,
  defaultTeacher,
  type AuditEvent,
  type Computer,
  type ComputerState,
  type FeatureAction,
  type TeacherProfile
} from "@bimleman/domain";
import type { ClassroomControlAdapter } from "./types";

export interface ActionReport {
  computerId: string;
  hostname: string;
  ok: boolean;
  state: ComputerState;
  message: string;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Action impossible.";
}

export class ClassroomController {
  readonly audit: AuditEvent[] = [];

  constructor(
    private readonly adapter: ClassroomControlAdapter,
    private readonly teacher: TeacherProfile = defaultTeacher
  ) {}

  stateOf(computer: Computer): ComputerState {
    return this.adapter.stateOf(computer);
  }

  async probe(computer: Computer): Promise<ComputerState> {
    this.guard(computer);
    try {
      const state = await this.adapter.probe(computer);
      this.record(computer, "probe", "success");
      return state;
    } catch (error) {
      this.record(computer, "probe", "failure");
      throw error;
    }
  }

  async probeMany(list: Computer[]): Promise<ActionReport[]> {
    const reports: ActionReport[] = [];
    let cursor = 0;
    const worker = async () => {
      while (cursor < list.length) {
        const computer = list[cursor];
        cursor += 1;
        reports.push(await this.one(computer, "probe", async () => {
          await this.adapter.probe(computer);
        }));
      }
    };
    await Promise.all(Array.from({ length: Math.min(6, list.length) }, () => worker()));
    return reports;
  }

  view(computer: Computer): Promise<ActionReport> {
    return this.one(computer, "view", () => this.adapter.view(computer));
  }

  control(computer: Computer): Promise<ActionReport> {
    return this.one(computer, "control", () => this.adapter.control(computer));
  }

  lock(computer: Computer): Promise<ActionReport> {
    return this.feature(computer, "lock");
  }

  unlock(computer: Computer): Promise<ActionReport> {
    return this.feature(computer, "unlock");
  }

  async message(list: Computer[], text: string): Promise<ActionReport[]> {
    const body = assertMessage(text);
    return this.many(list, "message", (computer) => this.adapter.feature(computer, "message", body));
  }

  async openWebsite(list: Computer[], url: string): Promise<ActionReport[]> {
    const target = assertWebsite(url);
    return this.many(list, "openWebsite", (computer) => this.adapter.feature(computer, "openWebsite", target));
  }

  reboot(list: Computer[], confirmed: boolean): Promise<ActionReport[]> {
    return this.power(list, "reboot", confirmed);
  }

  shutdown(list: Computer[], confirmed: boolean): Promise<ActionReport[]> {
    return this.power(list, "shutdown", confirmed);
  }

  thumbnail(computer: Computer): Promise<string | null> {
    this.guard(computer);
    return this.adapter.thumbnail(computer);
  }

  private feature(computer: Computer, action: FeatureAction, payload?: string): Promise<ActionReport> {
    return this.one(computer, action, () => this.adapter.feature(computer, action, payload));
  }

  private async power(list: Computer[], action: "reboot" | "shutdown", confirmed: boolean): Promise<ActionReport[]> {
    if (!confirmed) throw new ConfirmationRequiredError(action);
    return this.many(list, action, (computer) => this.adapter.feature(computer, action));
  }

  private async many(
    list: Computer[],
    action: string,
    run: (computer: Computer) => Promise<void>
  ): Promise<ActionReport[]> {
    const reports: ActionReport[] = [];
    for (const computer of list) reports.push(await this.one(computer, action, () => run(computer)));
    return reports;
  }

  private async one(computer: Computer, action: string, run: () => Promise<void>): Promise<ActionReport> {
    try {
      this.guard(computer);
      await run();
      this.record(computer, action, "success");
      return {
        computerId: computer.id,
        hostname: computer.hostname,
        ok: true,
        state: this.adapter.stateOf(computer),
        message: `${computer.hostname} : ${action} réussi.`
      };
    } catch (error) {
      this.record(computer, action, "failure");
      return {
        computerId: computer.id,
        hostname: computer.hostname,
        ok: false,
        state: safeState(this.adapter, computer),
        message: errorMessage(error)
      };
    }
  }

  private guard(computer: Computer): void {
    assertAuthorized(this.teacher, computer.roomId);
  }

  private record(computer: Computer, action: string, result: "success" | "failure"): void {
    this.audit.push(createAuditEvent({
      actor: this.teacher.actorId,
      action,
      result,
      computer
    }));
  }
}

function safeState(adapter: ClassroomControlAdapter, computer: Computer): ComputerState {
  try {
    return adapter.stateOf(computer);
  } catch {
    return "error";
  }
}
