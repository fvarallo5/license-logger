import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { friendly, listBillingCustomers, listInvoices, recordPayment } from "../lib/api";
import { statusTone } from "../lib/format";
import { useSchool } from "../session";
import type { Invoice } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader } from "../components/ui";

export default function PayPage() {
  const schoolId = useSchool().school_id;
  const [invoices, setInvoices] = useState<Invoice[] | null>(null);
  const [customers, setCustomers] = useState<{ id: string; display_name: string; student_id: string | null }[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [payFor, setPayFor] = useState<Invoice | null>(null);
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("cash");
  const [reference, setReference] = useState("");
  const [customerId, setCustomerId] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [inv, cust] = await Promise.all([listInvoices(supabase, schoolId), listBillingCustomers(supabase, schoolId).catch(() => [])]);
      setInvoices(inv);
      setCustomers(cust);
    } catch (e) {
      setErr(friendly(e));
      setInvoices([]);
    }
  }, [schoolId]);

  useEffect(() => {
    void load();
  }, [load]);

  function openPay(inv: Invoice) {
    setPayFor(inv);
    setAmount(String(inv.balance || inv.total || ""));
    setMethod("cash");
    setReference("");
    const match = customers.find((c) => c.student_id && c.student_id === inv.student_id);
    setCustomerId(match?.id ?? customers[0]?.id ?? "");
  }

  async function savePay() {
    if (!payFor || !customerId) return;
    setBusy(true);
    try {
      await recordPayment(supabase, {
        schoolId,
        customerId,
        invoiceId: payFor.id,
        studentId: payFor.student_id,
        amount: Number(amount),
        method,
        reference,
      });
      setPayFor(null);
      await load();
    } catch (e) {
      setErr(friendly(e));
    } finally {
      setBusy(false);
    }
  }

  const open = (invoices ?? []).filter((i) => i.status === "open" || i.status === "partially_paid" || i.status === "draft");

  return (
    <>
      <PageHeader title="Pay" desc="Invoices and payments. Package hours draw when lessons are marked taught.">
        <Link className="btn" to="/packages">
          Packages
        </Link>
        <Link className="btn" to="/quickbooks">
          QuickBooks
        </Link>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={load} />}
      <Card title="Open invoices" count={open.length}>
        {invoices === null ? (
          <Loading />
        ) : !invoices.length ? (
          <Empty>No invoices yet. Create one from QBO sync or after assigning a package (coming soon).</Empty>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="t">
              <thead>
                <tr>
                  <th>Doc</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th className="num">Total</th>
                  <th className="num">Balance</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {invoices.map((i) => (
                  <tr key={i.id}>
                    <td>{i.doc_number || i.id.slice(0, 8)}</td>
                    <td>{i.txn_date}</td>
                    <td>
                      <Badge tone={statusTone(i.status)}>{i.status}</Badge>
                    </td>
                    <td className="num">${Number(i.total).toFixed(2)}</td>
                    <td className="num">${Number(i.balance).toFixed(2)}</td>
                    <td>
                      {i.balance > 0 && i.status !== "void" && (
                        <button className="btn sm primary" onClick={() => openPay(i)}>
                          Record payment
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {payFor && (
        <Modal title="Record payment" onClose={() => setPayFor(null)}>
          <label>
            Customer
            <select value={customerId} onChange={(e) => setCustomerId(e.target.value)} required>
              <option value="">Select…</option>
              {customers.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.display_name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Amount
            <input type="number" min={0.01} step={0.01} value={amount} onChange={(e) => setAmount(e.target.value)} />
          </label>
          <label>
            Method
            <select value={method} onChange={(e) => setMethod(e.target.value)}>
              <option value="cash">Cash</option>
              <option value="card">Card</option>
              <option value="check">Check</option>
              <option value="ach">ACH</option>
              <option value="other">Other</option>
            </select>
          </label>
          <label>
            Reference
            <input value={reference} onChange={(e) => setReference(e.target.value)} placeholder="Check # / last4" />
          </label>
          <div className="row end">
            <button className="btn" onClick={() => setPayFor(null)}>
              Cancel
            </button>
            <button className="btn primary" disabled={busy || !customerId || !(Number(amount) > 0)} onClick={() => void savePay()}>
              Save payment
            </button>
          </div>
        </Modal>
      )}
    </>
  );
}
