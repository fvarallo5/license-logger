# Phase 2 — Plan

Uses live RPCs only: `add_slot_template`, `book_lesson`, `add_block`, `accept_reservation`, `decline_reservation`, plus SELECT on `slot_templates` / `reservations`.

**No migration required.** A future `generate_slots` RPC (materialize template windows into open holds) is deferred — open decision if schools need auto-generated open slots vs on-demand book.
