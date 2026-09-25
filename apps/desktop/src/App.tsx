import { useState } from "react";
import type { Computer } from "@bimleman/domain";
import type { PendingDialog } from "./use-classroom";
import { stateLabel, useClassroom, type RoomFilter } from "./use-classroom";

function roomComputers(roomId: string, computers: Computer[]): Computer[] {
  return computers.filter((computer) => computer.roomId === roomId);
}

export default function App() {
  const classroom = useClassroom();
  const activeName = classroom.activeRoom === "all"
    ? "Toutes les salles"
    : classroom.rooms.find((room) => room.id === classroom.activeRoom)?.name;

  return <div className="app-shell">
    <aside className="sidebar">
      <img className="brand" src="/logo.png" alt="BIMLéman View Room" />
      <div className="nav-title">Salles</div>
      <button className={classroom.activeRoom === "all" ? "room active" : "room"} onClick={() => classroom.setActiveRoom("all")}>
        <span>Tous</span><strong>24</strong>
      </button>
      {classroom.rooms.map((room) => <button key={room.id} className={room.id === classroom.activeRoom ? "room active" : "room"} onClick={() => classroom.setActiveRoom(room.id as RoomFilter)}>
        <span>{room.name}</span><strong>8</strong>
      </button>)}
      <div className="system-card">
        <span className={`dot ${classroom.platform.mode === "real" ? "green" : "amber"}`} />
        <div>
          <b>{classroom.platform.mode === "real" ? "Mode réel" : "Mode simulation"}</b>
          <small>{classroom.platform.os} · Veyon {classroom.platform.veyonFound ? "détecté" : "non détecté"}</small>
          <small>{classroom.counts.online}/24 joignables · {classroom.counts.offline} hors ligne · {classroom.counts.error} erreur(s)</small>
        </div>
      </div>
    </aside>
    <main>
      <header>
        <div>
          <p className="eyebrow">BIMLÉMAN · SUPERVISION PÉDAGOGIQUE</p>
          <h1>{activeName}</h1>
          <p>{classroom.visible.length} postes · réseau local · aucune capture enregistrée</p>
        </div>
        <button className="primary" onClick={() => void classroom.probeVisible()}>Tester {classroom.activeRoom === "all" ? "le parc" : "la salle"}</button>
      </header>
      <section className="toolbar" aria-label="Actions de sélection">
        <button onClick={classroom.selectVisible}>Sélectionner la vue</button>
        <button onClick={classroom.clearSelection}>Effacer</button>
        <span>{classroom.selected.length} sélectionné(s)</span>
        <button disabled={!classroom.selected.length} onClick={() => void classroom.lockMany(classroom.selectedComputers)}>Figer</button>
        <button disabled={!classroom.selected.length} onClick={() => void classroom.unlockMany(classroom.selectedComputers)}>Défiger</button>
        <button disabled={!classroom.selected.length} onClick={() => classroom.openDialog("message", classroom.selectedComputers)}>Message</button>
        <button disabled={!classroom.selected.length} onClick={() => classroom.openDialog("openWebsite", classroom.selectedComputers)}>URL</button>
        <button className="warn" disabled={!classroom.selected.length} onClick={() => classroom.openDialog("reboot", classroom.selectedComputers)}>Redémarrer</button>
        <button className="danger" disabled={!classroom.selected.length} onClick={() => classroom.openDialog("shutdown", classroom.selectedComputers)}>Éteindre</button>
      </section>
      {classroom.activeRoom !== "all" && <section className="toolbar room-toolbar" aria-label="Actions de salle">
        <span>Toute la salle</span>
        <button onClick={() => void classroom.lockMany(classroom.visible)}>Figer</button>
        <button onClick={() => void classroom.unlockMany(classroom.visible)}>Défiger</button>
        <button onClick={() => classroom.openDialog("message", classroom.visible)}>Message</button>
        <button onClick={() => classroom.openDialog("openWebsite", classroom.visible)}>URL</button>
        <button className="warn" onClick={() => classroom.openDialog("reboot", classroom.visible)}>Redémarrer</button>
        <button className="danger" onClick={() => classroom.openDialog("shutdown", classroom.visible)}>Éteindre</button>
      </section>}
      {classroom.activeRoom === "all"
        ? classroom.rooms.map((room) => <section key={room.id}>
          <div className="section-title"><h2>{room.name}</h2><button onClick={() => void classroom.lockMany(roomComputers(room.id, classroom.computers))}>Figer la salle</button></div>
          <ComputerGrid classroom={classroom} list={roomComputers(room.id, classroom.computers)} />
        </section>)
        : <ComputerGrid classroom={classroom} list={classroom.visible} />}
      <AuditPanel audit={classroom.audit} version={classroom.auditVersion} />
      <footer><span>{classroom.toast}</span><span>Les miniatures restent en mémoire et ne sont pas archivées.</span></footer>
      {classroom.dialog && <ActionDialog dialog={classroom.dialog} onCancel={() => classroom.setDialog(null)} onConfirm={classroom.confirmDialog} />}
    </main>
  </div>;
}

function ComputerGrid({ classroom, list }: { classroom: ReturnType<typeof useClassroom>; list: Computer[] }) {
  return <section className="grid">{list.map((computer) => {
    const state = classroom.states[computer.id] ?? "offline";
    const thumb = classroom.thumbs[computer.id];
    const reachable = state === "online" || state === "locked" || state === "controlled";
    return <article className={`computer-card ${classroom.selected.includes(computer.id) ? "selected" : ""}`} key={computer.id}>
      <label className="select"><input type="checkbox" checked={classroom.selected.includes(computer.id)} onChange={() => classroom.toggle(computer.id)} aria-label={`Sélectionner ${computer.hostname}`} /></label>
      <div className="screen">
        {thumb ? <img src={thumb} alt={`Miniature simulée ou distante de ${computer.hostname}`} /> : <div className="mock-screen"><span className="screen-logo">BL</span><span>{reachable ? "Miniature en attente" : "Pas d'image"}</span></div>}
      </div>
      <div className="card-head"><div><b>{computer.hostname}</b><small>Place {computer.seat}</small></div><span className={`status ${state}`}>{stateLabel(state)}</span></div>
      <div className="actions">
        <button disabled={!reachable} onClick={() => void classroom.view(computer)}>Voir</button>
        <button disabled={!reachable} onClick={() => void classroom.control(computer)}>Aider</button>
        <button disabled={!reachable} onClick={() => void (state === "locked" ? classroom.unlock(computer) : classroom.lock(computer))}>{state === "locked" ? "Défiger" : "Figer"}</button>
        <button disabled={!reachable} onClick={() => classroom.openDialog("message", [computer])}>Message</button>
        <button disabled={!reachable} onClick={() => classroom.openDialog("openWebsite", [computer])}>URL</button>
        <button className="warn" disabled={!reachable} onClick={() => classroom.openDialog("reboot", [computer])}>Redémarrer</button>
        <button className="danger" disabled={!reachable} onClick={() => classroom.openDialog("shutdown", [computer])}>Éteindre</button>
      </div>
    </article>;
  })}</section>;
}

function AuditPanel({ audit, version }: { audit: { at: string; actor: string; action: string; result: string; computerId?: string }[]; version: number }) {
  const rows = [...audit].reverse().slice(0, 40);
  return <section className="audit" aria-live="polite">
    <h2>Journal d'audit <small>{version > 0 ? `${audit.length} événement(s)` : "aucun événement"}</small></h2>
    {rows.length === 0 ? <p>Les actions formateur apparaîtront ici, sans contenu d'écran.</p> : <ul>{rows.map((event, index) => <li key={`${event.at}-${index}`} className={event.result}>
      <time dateTime={event.at}>{event.at.slice(11, 19)}</time>
      <span>{event.actor}</span>
      <span>{event.action}</span>
      <span>{event.computerId ?? "—"}</span>
      <span>{event.result === "success" ? "réussi" : "échec"}</span>
    </li>)}</ul>}
  </section>;
}

function ActionDialog({ dialog, onCancel, onConfirm }: {
  dialog: PendingDialog;
  onCancel: () => void;
  onConfirm: (value: string, acknowledged: boolean) => Promise<void>;
}) {
  const [value, setValue] = useState(dialog.kind === "openWebsite" ? "https://" : "");
  const [acknowledged, setAcknowledged] = useState(false);
  const power = dialog.kind === "reboot" || dialog.kind === "shutdown";
  const names = dialog.targets.map((computer) => computer.hostname).join(", ");
  return <div className="dialog-backdrop" role="presentation">
    <form className="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" onSubmit={(event) => {
      event.preventDefault();
      void onConfirm(value, acknowledged);
    }}>
      <h2 id="dialog-title">{dialog.title}</h2>
      <p>{dialog.targets.length} poste(s) : {names}</p>
      {dialog.kind === "message" && <textarea autoFocus required maxLength={500} value={value} onChange={(event) => setValue(event.target.value)} placeholder="Consigne affichée sur les postes" />}
      {dialog.kind === "openWebsite" && <input autoFocus required type="url" value={value} onChange={(event) => setValue(event.target.value)} placeholder="https://…" />}
      {power && <label className="confirm-line"><input type="checkbox" checked={acknowledged} onChange={(event) => setAcknowledged(event.target.checked)} /> Je confirme cette action, qui interrompt le travail des élèves.</label>}
      <div className="dialog-actions">
        <button type="button" onClick={onCancel}>Annuler</button>
        <button className={dialog.kind === "shutdown" ? "danger" : "primary"} type="submit" disabled={power && !acknowledged}>{dialog.kind === "shutdown" ? "Éteindre" : "Confirmer"}</button>
      </div>
    </form>
  </div>;
}
