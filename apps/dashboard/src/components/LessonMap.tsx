import { useEffect, useRef } from "react";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { Lesson, Lot } from "../lib/types";
import { pinForLesson, statusColor } from "../lib/lessonPins";

/** CSS pin — avoids Leaflet default PNG URLs that break under Vite. */
function lotPinIcon() {
  return L.divIcon({
    className: "lot-pin",
    html: '<span class="lot-pin-dot"></span>',
    iconSize: [22, 22],
    iconAnchor: [11, 11],
  });
}

const OSM_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';

function circleIcon(color: string, selected: boolean) {
  const size = selected ? 16 : 12;
  return L.divIcon({
    className: "ll-pin",
    html: `<span style="display:block;width:${size}px;height:${size}px;border-radius:50%;background:${color};border:2px solid #fff;box-shadow:0 0 0 ${selected ? 3 : 1}px ${color}"></span>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}

export function LessonMap({
  lessons,
  lots,
  names,
  selectedId,
  onSelect,
}: {
  lessons: Lesson[];
  lots: Lot[];
  names: Record<string, string>;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}) {
  const host = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layerRef = useRef<L.LayerGroup | null>(null);
  const onSelectRef = useRef(onSelect);
  onSelectRef.current = onSelect;

  useEffect(() => {
    if (!host.current || mapRef.current) return;
    const map = L.map(host.current, { scrollWheelZoom: false }).setView([39.8283, -98.5795], 4);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: OSM_ATTR, maxZoom: 19 }).addTo(map);
    layerRef.current = L.layerGroup().addTo(map);
    mapRef.current = map;
    const onResize = () => map.invalidateSize();
    window.addEventListener("resize", onResize);
    window.setTimeout(onResize, 80);
    return () => {
      window.removeEventListener("resize", onResize);
      map.remove();
      mapRef.current = null;
      layerRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    const layer = layerRef.current;
    if (!map || !layer) return;
    layer.clearLayers();
    const bounds: L.LatLngExpression[] = [];

    for (const lot of lots) {
      if (lot.lat == null || lot.lng == null) continue;
      const ll: L.LatLngExpression = [Number(lot.lat), Number(lot.lng)];
      bounds.push(ll);
      L.marker(ll, { icon: lotPinIcon() })
        .bindPopup(`<strong>${escapeHtml(lot.name)}</strong><br/>Lot`)
        .addTo(layer);
    }

    for (const lesson of lessons) {
      const pin = pinForLesson(lesson, lots);
      if (!pin) continue;
      const selected = selectedId === pin.lessonId;
      const color = statusColor(lesson.status);
      const ll: L.LatLngExpression = [pin.lat, pin.lng];
      bounds.push(ll);
      const m = L.marker(ll, { icon: circleIcon(color, selected), zIndexOffset: selected ? 500 : 0 })
        .bindPopup(
          `<strong>${escapeHtml(lesson.kind || "Lesson")}</strong><br/>${escapeHtml(names[lesson.instructor_id] || "Instructor")}<br/>${escapeHtml(pin.label)} · ${escapeHtml(lesson.status)}`,
        )
        .addTo(layer);
      m.on("click", () => onSelectRef.current(pin.lessonId));
      if (selected) {
        m.openPopup();
        map.panTo(ll, { animate: true });
      }
    }

    if (bounds.length) map.fitBounds(L.latLngBounds(bounds).pad(0.35), { maxZoom: 14 });
    window.setTimeout(() => map.invalidateSize(), 60);
  }, [lessons, lots, names, selectedId]);

  const hasPins = lots.some((l) => l.lat != null) || lessons.some((l) => pinForLesson(l, lots));

  return (
    <div className="ll-lesson-map">
      {!hasPins ? <div className="ll-map-empty">No locations yet — pin a lot on Fleet to place lessons on the map.</div> : null}
      <div ref={host} className="ll-lesson-map-canvas" role="application" aria-label="Lessons map" title="Lessons map" />
      <p className="muted ll-map-help">Lots + pickup pins for visible lessons · click a pin to select</p>
    </div>
  );
}

function escapeHtml(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
