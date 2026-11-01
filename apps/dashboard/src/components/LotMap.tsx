import { useEffect, useRef, useState } from "react";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { Lot } from "../lib/types";

/** CSS pin — avoids Leaflet default PNG URLs that break under Vite/Workers Builds. */
function pinIcon() {
  return L.divIcon({
    className: "lot-pin",
    html: '<span class="lot-pin-dot"></span>',
    iconSize: [22, 22],
    iconAnchor: [11, 11],
  });
}

const OSM_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';
const DEFAULT_CENTER: L.LatLngExpression = [39.8283, -98.5795]; // continental US
const DEFAULT_ZOOM = 4;

type NominatimHit = { lat: string; lon: string; display_name: string };

async function geocode(q: string): Promise<NominatimHit[]> {
  const url = "https://nominatim.openstreetmap.org/search?" + new URLSearchParams({ q, format: "json", limit: "5" }).toString();
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
  });
  if (!res.ok) throw new Error("Address search failed");
  return (await res.json()) as NominatimHit[];
}

export function LotMap({
  lots,
  schoolCity,
  onPin,
}: {
  lots: Lot[];
  schoolCity?: string | null;
  /** Persist a pin on the first lot without coords, or the default lot. */
  onPin: (lotId: string, lat: number, lng: number) => Promise<void>;
}) {
  const host = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layerRef = useRef<L.LayerGroup | null>(null);
  const [query, setQuery] = useState(schoolCity?.trim() || "");
  const [hits, setHits] = useState<NominatimHit[]>([]);
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const pinned = lots.filter((l) => l.lat != null && l.lng != null);
  const targetLot = lots.find((l) => l.is_default) ?? lots.find((l) => l.lat == null || l.lng == null) ?? lots[0] ?? null;

  // Init map once
  useEffect(() => {
    if (!host.current || mapRef.current) return;
    const map = L.map(host.current, { scrollWheelZoom: false }).setView(DEFAULT_CENTER, DEFAULT_ZOOM);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: OSM_ATTR,
      maxZoom: 19,
    }).addTo(map);
    layerRef.current = L.layerGroup().addTo(map);
    mapRef.current = map;

    map.on("click", (e: L.LeafletMouseEvent) => {
      if (!targetLot) {
        setHint("Add a lot first, then click the map to pin it.");
        return;
      }
      setHint(`Pinning ${targetLot.name}…`);
      void onPin(targetLot.id, e.latlng.lat, e.latlng.lng)
        .then(() => setHint(`Saved pin for ${targetLot.name}.`))
        .catch((ex: Error) => setErr(ex.message));
    });

    return () => {
      map.remove();
      mapRef.current = null;
      layerRef.current = null;
    };
    // targetLot / onPin intentionally omitted — handlers read latest via closure refresh below
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Refresh click handler when target lot changes
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    map.off("click");
    map.on("click", (e: L.LeafletMouseEvent) => {
      if (!targetLot) {
        setHint("Add a lot first, then click the map to pin it.");
        return;
      }
      setHint(`Pinning ${targetLot.name}…`);
      void onPin(targetLot.id, e.latlng.lat, e.latlng.lng)
        .then(() => setHint(`Saved pin for ${targetLot.name}.`))
        .catch((ex: Error) => setErr(ex.message));
    });
  }, [targetLot, onPin]);

  // Draw pins + fit bounds; geocode school city when nothing pinned
  useEffect(() => {
    const map = mapRef.current;
    const layer = layerRef.current;
    if (!map || !layer) return;
    layer.clearLayers();

    if (pinned.length) {
      const latLngs: L.LatLngExpression[] = [];
      for (const l of pinned) {
        const ll: L.LatLngExpression = [Number(l.lat), Number(l.lng)];
        latLngs.push(ll);
        L.marker(ll, { icon: pinIcon() })
          .bindPopup(`<strong>${escapeHtml(l.name)}</strong>`)
          .addTo(layer);
      }
      map.fitBounds(L.latLngBounds(latLngs).pad(0.25), { maxZoom: 14 });
      return;
    }

    let cancelled = false;
    const city = schoolCity?.trim();
    if (city) {
      void geocode(city)
        .then((rows) => {
          if (cancelled || !rows[0]) {
            map.setView(DEFAULT_CENTER, DEFAULT_ZOOM);
            return;
          }
          map.setView([Number(rows[0].lat), Number(rows[0].lon)], 12);
          setHint(`Centered on ${city}. Click the map (or search an address) to pin ${targetLot?.name ?? "a lot"}.`);
        })
        .catch(() => map.setView(DEFAULT_CENTER, DEFAULT_ZOOM));
    } else {
      map.setView(DEFAULT_CENTER, DEFAULT_ZOOM);
      setHint("Search an address or click the map to pin your lot. No API key needed (OpenStreetMap).");
    }
    return () => {
      cancelled = true;
    };
  }, [pinned, schoolCity, targetLot?.id, targetLot?.name]);

  async function search() {
    const q = query.trim();
    if (!q) return;
    setBusy(true);
    setErr(null);
    setHits([]);
    try {
      const rows = await geocode(q);
      setHits(rows);
      if (!rows.length) setHint("No matches — try a fuller address (street, city, state).");
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function pickHit(h: NominatimHit) {
    const map = mapRef.current;
    if (!map) return;
    const lat = Number(h.lat);
    const lng = Number(h.lon);
    map.setView([lat, lng], 15);
    setHits([]);
    if (!targetLot) {
      setHint("Add a lot, then search again or click the map.");
      return;
    }
    setHint(`Pinning ${targetLot.name} at this address…`);
    void onPin(targetLot.id, lat, lng)
      .then(() => setHint(`Saved pin for ${targetLot.name}.`))
      .catch((ex: Error) => setErr(ex.message));
  }

  return (
    <div className="lot-map">
      <div className="lot-map-toolbar">
        <input
          aria-label="Search address"
          placeholder={schoolCity ? `e.g. ${schoolCity}` : "Street, city, state"}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              void search();
            }
          }}
        />
        <button type="button" className="btn sm primary" disabled={busy || !query.trim()} onClick={() => void search()}>
          {busy ? "…" : "Search"}
        </button>
      </div>
      {hits.length > 0 && (
        <ul className="lot-map-hits" role="listbox" aria-label="Address matches">
          {hits.map((h) => (
            <li key={`${h.lat},${h.lon},${h.display_name}`}>
              <button type="button" className="btn link" onClick={() => pickHit(h)}>
                {h.display_name}
              </button>
            </li>
          ))}
        </ul>
      )}
      <div ref={host} className="lot-map-canvas" role="application" aria-label="Lots map" title="Lots map" />
      <p className="muted lot-map-help">
        {hint ??
          (pinned.length
            ? "Drag or zoom · click to move the default lot pin"
            : "No pins yet — search an address or click the map. Uses OpenStreetMap (no API key).")}
      </p>
      {err && (
        <div className="alert bad" role="alert">
          {err}
        </div>
      )}
    </div>
  );
}

function escapeHtml(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
