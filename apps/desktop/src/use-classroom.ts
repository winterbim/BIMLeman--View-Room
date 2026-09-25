import { useCallback, useEffect, useMemo, useState } from "react";
import { computers, rooms, type Computer, type ComputerState } from "@bimleman/domain";
import { ClassroomController, MockVeyonAdapter, VeyonWindowsAdapter, type ActionReport } from "@bimleman/veyon-adapter";
import { appendAudit, platformInfo, tauriTransport, type PlatformInfo } from "./tauri";

export type RoomFilter = "all" | "room-a" | "room-b" | "room-c";

export interface PendingDialog {
  kind: "message" | "openWebsite" | "reboot" | "shutdown";
  targets: Computer[];
  title: string;
}

const STATE_LABEL: Record<ComputerState, string> = {
  online: "En ligne",
  offline: "Hors ligne",
  locked: "Figé",
  controlled: "Assistance",
  error: "Erreur"
};

export function stateLabel(state: ComputerState): string {
  return STATE_LABEL[state];
}

function summarize(reports: ActionReport[]): string {
  const ok = reports.filter((report) => report.ok).length;
  const failed = reports.length - ok;
  if (failed === 0) return `${ok}/${reports.length} action(s) réussie(s).`;
  const first = reports.find((report) => !report.ok);
  return `${ok}/${reports.length} réussie(s), ${failed} échec(s). ${first?.message ?? ""}`.trim();
}

export function useClassroom() {
  const [platform, setPlatform] = useState<PlatformInfo>({ os: "loading", veyonFound: false, mode: "mock" });
  const [controller, setController] = useState<ClassroomController | null>(null);
  const [activeRoom, setActiveRoom] = useState<RoomFilter>("room-a");
  const [states, setStates] = useState<Record<string, ComputerState>>({});
  const [thumbs, setThumbs] = useState<Record<string, string>>({});
  const [selected, setSelected] = useState<string[]>([]);
  const [toast, setToast] = useState("Prêt");
  const [dialog, setDialog] = useState<PendingDialog | null>(null);
  const [auditVersion, setAuditVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;
    platformInfo().then((info) => {
      if (cancelled) return;
      const adapter = info.mode === "real"
        ? new VeyonWindowsAdapter(tauriTransport)
        : new MockVeyonAdapter({ recoverPowerMs: 2500 });
      const next = new ClassroomController(adapter);
      const initial: Record<string, ComputerState> = {};
      for (const computer of computers) initial[computer.id] = next.stateOf(computer);
      setPlatform(info);
      setController(next);
      setStates(initial);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const visible = useMemo(
    () => computers.filter((computer) => activeRoom === "all" || computer.roomId === activeRoom),
    [activeRoom]
  );

  const applyReports = useCallback((reports: ActionReport[]) => {
    setStates((current) => {
      const next = { ...current };
      for (const report of reports) next[report.computerId] = report.state;
      return next;
    });
    setToast(summarize(reports));
    setAuditVersion((value) => value + 1);
    if (controller) {
      for (const event of controller.audit.slice(-reports.length)) {
        void appendAudit({
          actor: event.actor,
          action: event.action,
          result: event.result,
          computerId: event.computerId,
          roomId: event.roomId
        });
      }
    }
  }, [controller]);

  const runOne = useCallback(async (computer: Computer, action: (target: Computer) => Promise<ActionReport>) => {
    if (!controller) return;
    applyReports([await action(computer)]);
  }, [applyReports, controller]);

  const probeVisible = useCallback(async () => {
    if (!controller) return;
    setToast("Test des postes en cours…");
    applyReports(await controller.probeMany(visible));
  }, [applyReports, controller, visible]);

  useEffect(() => {
    if (!controller || platform.mode !== "mock") return;
    const targets = visible.filter((computer) => {
      const state = states[computer.id];
      return state === "online" || state === "locked" || state === "controlled";
    });
    let cancelled = false;
    const refresh = async () => {
      if (document.hidden) return;
      for (const computer of targets) {
        if (cancelled) return;
        const image = await controller.thumbnail(computer);
        if (cancelled || !image) continue;
        setThumbs((current) => current[computer.id] === image ? current : { ...current, [computer.id]: image });
      }
    };
    void refresh();
    const timer = setInterval(() => void refresh(), 4000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [controller, platform.mode, visible, states]);

  useEffect(() => {
    if (!controller || platform.mode !== "real") return;
    let cancelled = false;
    const refresh = async () => {
      if (document.hidden) return;
      const targets = visible.filter((computer) => {
        const state = states[computer.id];
        return state === "online" || state === "locked" || state === "controlled";
      });
      let cursor = 0;
      const worker = async () => {
        while (cursor < targets.length && !cancelled) {
          const computer = targets[cursor];
          cursor += 1;
          if (!computer) return;
          const image = await controller.thumbnail(computer);
          if (image && !cancelled) {
            setThumbs((current) => ({ ...current, [computer.id]: image }));
          }
        }
      };
      await Promise.all(Array.from({ length: Math.min(4, targets.length) }, () => worker()));
    };
    const timer = setInterval(() => void refresh(), 4000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [controller, platform.mode, visible, states]);

  const selectedComputers = computers.filter((computer) => selected.includes(computer.id));

  function toggle(id: string) {
    setSelected((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  function openDialog(kind: PendingDialog["kind"], targets: Computer[]) {
    if (!targets.length) {
      setToast("Sélectionnez au moins un poste.");
      return;
    }
    const titles = {
      message: "Envoyer un message",
      openWebsite: "Ouvrir une adresse web",
      reboot: "Redémarrer les postes",
      shutdown: "Éteindre les postes"
    } as const;
    setDialog({ kind, targets, title: titles[kind] });
  }

  async function confirmDialog(value: string, acknowledged: boolean) {
    if (!controller || !dialog) return;
    const targets = dialog.targets;
    const kind = dialog.kind;
    setDialog(null);
    try {
      if (kind === "message") applyReports(await controller.message(targets, value));
      if (kind === "openWebsite") applyReports(await controller.openWebsite(targets, value));
      if (kind === "reboot") applyReports(await controller.reboot(targets, acknowledged));
      if (kind === "shutdown") applyReports(await controller.shutdown(targets, acknowledged));
    } catch (error) {
      setToast(error instanceof Error ? error.message : "Action impossible.");
    }
  }

  const counts = {
    total: computers.length,
    online: Object.values(states).filter((state) => state === "online" || state === "locked" || state === "controlled").length,
    offline: Object.values(states).filter((state) => state === "offline").length,
    error: Object.values(states).filter((state) => state === "error").length,
    locked: Object.values(states).filter((state) => state === "locked").length
  };

  return {
    platform,
    rooms,
    computers,
    activeRoom,
    setActiveRoom: (room: RoomFilter) => {
      setActiveRoom(room);
      setSelected([]);
    },
    visible,
    states,
    thumbs,
    selected,
    selectedComputers,
    toggle,
    selectVisible: () => setSelected(visible.map((computer) => computer.id)),
    clearSelection: () => setSelected([]),
    toast,
    dialog,
    setDialog,
    confirmDialog,
    openDialog,
    audit: controller?.audit ?? [],
    auditVersion,
    counts,
    probeVisible,
    view: (computer: Computer) => runOne(computer, (target) => controller!.view(target)),
    control: (computer: Computer) => runOne(computer, (target) => controller!.control(target)),
    lock: (computer: Computer) => runOne(computer, (target) => controller!.lock(target)),
    unlock: (computer: Computer) => runOne(computer, (target) => controller!.unlock(target)),
    lockMany: async (targets: Computer[]) => {
      if (!controller) return;
      const reports: ActionReport[] = [];
      for (const target of targets) reports.push(await controller.lock(target));
      applyReports(reports);
    },
    unlockMany: async (targets: Computer[]) => {
      if (!controller) return;
      const reports: ActionReport[] = [];
      for (const target of targets) reports.push(await controller.unlock(target));
      applyReports(reports);
    }
  };
}
