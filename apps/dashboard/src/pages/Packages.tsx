import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { deactivatePackage, friendly, listPackageCatalog, upsertPackageCatalog } from "../lib/api";
import { useSchool } from "../session";
import type { PackageCatalog } from "../lib/types";
import { Card, Empty, ErrorBox, Loading, Modal, PageHeader } from "../components/ui";

export default function PackagesPage() {
  const schoolId = useSchool().school_id;
  const [rows, setRows] = useState<PackageCatalog[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [show, setShow] = useState(false);
  const [edit, setEdit] = useState<PackageCatalog | null>(null);
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState("");
  const [hours, setHours] = useState("6");
  const [price, setPrice] = useState("0");
  const [kind, setKind] = useState("btw");

  const load = useCallback(async () => {
    setErr(null);
    try {
      setRows(await listPackageCatalog(supabase, schoolId));
    } catch (e) {
      setErr(friendly(e));
      setRows([]);
    }
  }, [schoolId]);

  useEffect(() => {
    void load();
  }, [load]);

  function openNew() {
    setEdit(null);
    setName("");
    setHours("6");
    setPrice("0");
    setKind("btw");
    setShow(true);
  }
  function openEdit(r: PackageCatalog) {
    setEdit(r);
    setName(r.name);
    setHours(String(r.hours));
    setPrice(String(r.price));
    setKind(r.kind);
    setShow(true);
  }

  async function save() {
    setBusy(true);
    setErr(null);
    try {
      await upsertPackageCatalog(supabase, {
        id: edit?.id,
        schoolId,
        name: name.trim(),
        hours: Number(hours),
        price: Number(price),
        kind,
      });
      setShow(false);
      await load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  async function deactivate(r: PackageCatalog) {
    if (!confirm(`Deactivate “${r.name}”?`)) return;
    await deactivatePackage(supabase, schoolId, r.id);
    await load();
  }

  return (
    <>
      <PageHeader title="Packages" desc="Price book for BTW and other lesson packages. Assign on enroll or from a student.">
        <button className="btn primary" onClick={openNew}>
          + Package
        </button>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={load} />}
      <Card title="Catalog" count={rows?.length ?? 0}>
        {rows === null ? (
          <Loading />
        ) : !rows.length ? (
          <Empty>No active packages. Add a 6 / 10 / 14-hour BTW package to get started.</Empty>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="t">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Kind</th>
                  <th className="num">Hours</th>
                  <th className="num">Price</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.name}</td>
                    <td>{r.kind}</td>
                    <td className="num">{r.hours}</td>
                    <td className="num">${Number(r.price).toFixed(2)}</td>
                    <td className="row nowrap">
                      <button className="btn sm" onClick={() => openEdit(r)}>
                        Edit
                      </button>
                      <button className="btn sm danger" onClick={() => void deactivate(r)}>
                        Deactivate
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {show && (
        <Modal title={edit ? "Edit package" : "New package"} onClose={() => setShow(false)}>
          <label>
            Name
            <input value={name} onChange={(e) => setName(e.target.value)} required />
          </label>
          <label>
            Kind
            <select value={kind} onChange={(e) => setKind(e.target.value)}>
              <option value="btw">Behind-the-wheel</option>
              <option value="observation">Observation</option>
              <option value="road_test">Road test</option>
              <option value="other">Other</option>
            </select>
          </label>
          <label>
            Hours
            <input type="number" min={0.5} step={0.5} value={hours} onChange={(e) => setHours(e.target.value)} />
          </label>
          <label>
            Price
            <input type="number" min={0} step={0.01} value={price} onChange={(e) => setPrice(e.target.value)} />
          </label>
          <div className="row end">
            <button className="btn" onClick={() => setShow(false)}>
              Cancel
            </button>
            <button className="btn primary" disabled={busy || !name.trim()} onClick={() => void save()}>
              Save
            </button>
          </div>
        </Modal>
      )}
    </>
  );
}
