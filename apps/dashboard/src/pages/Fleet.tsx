import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import { addCar, addLot, friendly, listCars, listLots, membersPage, profileNames, updateCarCompliance, updateLotCoords } from "../lib/api";
import { useSchool } from "../session";
import { LotMap } from "../components/LotMap";
import type { Car, Lot, Member } from "../lib/types";
import { Card, Empty, ErrorBox, Loading, Modal, PageHeader } from "../components/ui";

function dueTone(d: string | null | undefined): string {
  if (!d) return "";
  const days = (new Date(d).getTime() - Date.now()) / 86400000;
  if (days < 0) return "bad";
  if (days < 30) return "warn";
  return "ok";
}

export default function FleetPage() {
  const membership = useSchool();
  const schoolId = membership.school_id;
  const schoolCity = membership.schools?.city ?? "";
  const [cars, setCars] = useState<Car[] | null>(null);
  const [lots, setLots] = useState<Lot[]>([]);
  const [instructors, setInstructors] = useState<Member[]>([]);
  const [names, setNames] = useState<Record<string, string>>({});
  const [err, setErr] = useState<string | null>(null);
  const [showCar, setShowCar] = useState(false);
  const [showLot, setShowLot] = useState(false);
  const [editCar, setEditCar] = useState<Car | null>(null);
  const [carName, setCarName] = useState("");
  const [plate, setPlate] = useState("");
  const [lotName, setLotName] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [c, l, mem] = await Promise.all([
        listCars(supabase, schoolId),
        listLots(supabase, schoolId),
        membersPage(supabase, schoolId, 0),
      ]);
      setCars(c);
      setLots(l);
      const inst = mem.rows.filter((m) => ["instructor", "owner", "admin"].includes(m.role));
      setInstructors(inst);
      setNames(
        await profileNames(
          supabase,
          inst.map((m) => m.user_id),
        ),
      );
    } catch (e) {
      setErr(friendly(e));
      setCars([]);
    }
  }, [schoolId]);

  useEffect(() => {
    void load();
  }, [load]);

  const mapLots = useMemo(() => lots.filter((l) => l.lat != null && l.lng != null), [lots]);

  async function saveCar() {
    setBusy(true);
    try {
      await addCar(supabase, { schoolId, name: carName.trim(), plate });
      setShowCar(false);
      setCarName("");
      setPlate("");
      await load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  async function saveLot() {
    setBusy(true);
    try {
      await addLot(supabase, schoolId, lotName.trim(), lots.length === 0);
      setShowLot(false);
      setLotName("");
      await load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  async function saveCompliance() {
    if (!editCar) return;
    setBusy(true);
    try {
      await updateCarCompliance(supabase, editCar.id, schoolId, {
        service_due: editCar.service_due ?? null,
        inspect_due: editCar.inspect_due ?? null,
        reg_due: editCar.reg_due ?? null,
        ins_due: editCar.ins_due ?? null,
        dual_control: editCar.dual_control,
        notes: editCar.notes ?? "",
        assigned_user_id: editCar.assigned_user_id,
        odo_miles: editCar.odo_miles ?? 0,
      });
      setEditCar(null);
      await load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeader title="Fleet" desc="Cars, Compliance Dates, And Lots. Due Dates Turn Amber Within 30 Days.">
        <button className="btn" onClick={() => setShowLot(true)}>
          + Lot
        </button>
        <button className="btn primary" onClick={() => setShowCar(true)}>
          + Car
        </button>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={load} />}

      <Card title="Map" count={mapLots.length ? `${mapLots.length} pinned` : undefined}>
        {!lots.length ? (
          <Empty>Add a lot, then search an address or click the map to pin it. OpenStreetMap — no API key.</Empty>
        ) : (
          <LotMap
            lots={lots}
            schoolCity={schoolCity}
            onPin={async (lotId, lat, lng) => {
              await updateLotCoords(supabase, lotId, schoolId, lat, lng);
              await load();
            }}
          />
        )}
        {lots.length > 0 && (
          <ul className="fleet-lots">
            {lots.map((l) => (
              <li key={l.id}>
                <strong>{l.name}</strong>
                {l.is_default && <span className="pill">default</span>}
                <span className="muted">
                  {l.lat != null && l.lng != null ? `${Number(l.lat).toFixed(5)}, ${Number(l.lng).toFixed(5)}` : "not pinned yet"}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card title="Cars" count={cars?.length ?? 0}>
        {cars === null ? (
          <Loading />
        ) : !cars.length ? (
          <Empty>No cars yet. Add the dual-control vehicles instructors drive.</Empty>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="t">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Plate</th>
                  <th>Instructor</th>
                  <th>Service</th>
                  <th>Reg</th>
                  <th>Ins</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {cars.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <span className="car-dot" style={{ background: c.color }} /> {c.name}
                      {c.dual_control ? "" : " · no dual"}
                    </td>
                    <td>{c.plate || "—"}</td>
                    <td>{c.assigned_user_id ? (names[c.assigned_user_id] ?? "…") : "—"}</td>
                    <td className={dueTone(c.service_due)}>{c.service_due ?? "—"}</td>
                    <td className={dueTone(c.reg_due)}>{c.reg_due ?? "—"}</td>
                    <td className={dueTone(c.ins_due)}>{c.ins_due ?? "—"}</td>
                    <td>
                      <button className="btn sm" onClick={() => setEditCar({ ...c })}>
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {showCar && (
        <Modal title="Add Car" onClose={() => setShowCar(false)}>
          <label>
            Name
            <input value={carName} onChange={(e) => setCarName(e.target.value)} required />
          </label>
          <label>
            Plate
            <input value={plate} onChange={(e) => setPlate(e.target.value)} />
          </label>
          <div className="row end">
            <button className="btn" onClick={() => setShowCar(false)}>
              Cancel
            </button>
            <button className="btn primary" disabled={busy || !carName.trim()} onClick={() => void saveCar()}>
              Add
            </button>
          </div>
        </Modal>
      )}
      {showLot && (
        <Modal title="Add Lot" onClose={() => setShowLot(false)}>
          <label>
            Name
            <input value={lotName} onChange={(e) => setLotName(e.target.value)} required />
          </label>
          <div className="row end">
            <button className="btn" onClick={() => setShowLot(false)}>
              Cancel
            </button>
            <button className="btn primary" disabled={busy || !lotName.trim()} onClick={() => void saveLot()}>
              Add
            </button>
          </div>
        </Modal>
      )}
      {editCar && (
        <Modal title={`Edit ${editCar.name}`} onClose={() => setEditCar(null)}>
          <label>
            Assigned instructor
            <select
              value={editCar.assigned_user_id ?? ""}
              onChange={(e) => setEditCar({ ...editCar, assigned_user_id: e.target.value || null })}
            >
              <option value="">Unassigned</option>
              {instructors.map((m) => (
                <option key={m.user_id} value={m.user_id}>
                  {names[m.user_id] ?? m.user_id.slice(0, 8)}
                </option>
              ))}
            </select>
          </label>
          <label className="row">
            <input
              type="checkbox"
              checked={editCar.dual_control}
              onChange={(e) => setEditCar({ ...editCar, dual_control: e.target.checked })}
            />{" "}
            Dual control
          </label>
          {(["service_due", "inspect_due", "reg_due", "ins_due"] as const).map((k) => (
            <label key={k}>
              {k.replace("_", " ")}
              <input type="date" value={editCar[k] ?? ""} onChange={(e) => setEditCar({ ...editCar, [k]: e.target.value || null })} />
            </label>
          ))}
          <label>
            Notes
            <input value={editCar.notes ?? ""} onChange={(e) => setEditCar({ ...editCar, notes: e.target.value })} />
          </label>
          <div className="row end">
            <button className="btn" onClick={() => setEditCar(null)}>
              Cancel
            </button>
            <button className="btn primary" disabled={busy} onClick={() => void saveCompliance()}>
              Save
            </button>
          </div>
        </Modal>
      )}
    </>
  );
}
