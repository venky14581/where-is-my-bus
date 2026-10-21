# Presentation script: two phones and the laptop

About 10 minutes. Two phones on USB to the laptop, the laptop on the
projector showing the office dashboard.

| Device | Role | Signed in as |
| --- | --- | --- |
| Phone A (Infinix) | Driver of bus TN 37 AB 1201 | `DRV001` |
| Phone B (OPPO) | Day scholar on the Gandhipuram route | the demo student, `cb.en.u4cse00001@cb.students.amrita.edu` |
| Laptop | Transport office | `transport.office@cb.amrita.edu` |

Passwords and PINs are in `scripts/seed-emulators.mjs`.

## 30 minutes before

1. On the laptop, start the server and load the demo data, each in its own
   terminal, in this order:
   ```bash
   npm run emulators
   ```
   ```bash
   npm run seed
   ```
   ```bash
   npm run demo-ready
   ```
   `demo-ready` gives the demo student a pass, sets fares, makes the
   evening buses, adds sample bus and train timings and wakes the server
   (about 30 s).
2. Start the dashboard (`cd dashboard`, then `npm run dev`), open
   http://localhost:5173 in Chrome and sign in as the office. Click
   **Sound on** once so the browser allows the alert sounds.
3. Plug in both phones. On each, choose **File transfer** in the USB
   notification and allow USB debugging. Keep both cables in for the whole
   talk: the phones reach the server through them.
4. Run the port forwarding for both phones
   (`adb reverse` for 9099, 8080, 9000, 5001 and 5173).
5. **Phone B (student):** sign in as the demo student. Choose
   Coimbatore → Gandhipuram – Campus → **Ukkadam**.
6. **Phone A (driver):** sign in as `DRV001`. If a trip is running, tap
   **End Trip**. Turn on **Demo drive (test mode)**. Do not start the trip yet.
7. Optional: mirror the phones on the projector (Android's Cast, or
   `scrcpy`) so the room can see them.
8. Do one quick run of steps 1 to 3 below, then end the trip again.

## The demo

### 1. The problem (laptop, 30 s)

"Day scholars wait at the stop not knowing where the college bus is. No GPS
box is fitted in the buses. Our app turns the driver's phone into the
tracker."

### 2. The driver starts the trip (Phone A, 1 min)

- Tap the big green **Start Trip**.
- Point out: one huge button, Tamil and English, the green **Sharing bus
  location** banner, next stop and stops reached.
- Laptop: a **Trip started** pop-up with a chime, and the bus appears on the
  live map.

### 3. The student sees the bus live (Phone B, 1.5 min)

- The bus moves on the map **every second** along the real road.
- The coloured card shows **Arrives in N min, around HH:MM**, and the
  **Live · updated 1 s ago** pill.
- Tap **See all stops**: passed stops with times, where the bus is, expected
  times for the rest.
- "Only the bus's location is shared, never the student's."

### 4. Bus pass and boarding (both phones, 1 min)

- Phone B: tap the **QR icon** at the top. The pass QR changes every
  30 seconds, so a screenshot is useless.
- Phone A: tap **Scan pass**, point the camera at Phone B. Shows
  **Demo Student – boarded**. Scan again: **already boarded**.

### 5. Driver reports a delay (Phone A then laptop, 1 min)

- Phone A: tap **Running late**.
- Phone B: the bell gets a badge; the alert is in the list.
- Laptop: a **Driver reports: running late** pop-up with sound.

### 6. Missed the bus (Phone B, 1 min)

- Tap **Missed your bus?**
- Other college buses the office allows (if one is running) with the nearest
  stop you can reach in time and seats left; hold a seat in one tap.
- Below: **Public bus and train** with the next town buses and trains for
  this route, entered by the office on the dashboard's Public transport page.
- To show another college bus, run this on the laptop first (bus-02, the
  R.S. Puram route, drives for about 8 minutes):
  ```bash
  npm run simulate-bus -- bus-02 --trip
  ```

### 7. Evening seat for a hosteller (Phone B, 1.5 min)

- Tap **Evening seats**. Today's and tomorrow's evening buses with fare and
  seats left; the student's own route says **Your bus pass covers this bus**.
- On another route, **Book a seat** → choose where to get off →
  **Book for ₹40** → the checkout (UPI / card / net banking) → **Pay**.
  "Demo money only."
- The ticket QR appears. "It works for one scan only." (Scanning it on
  Phone A's bus says the ticket is for another bus, which is correct: it is
  for the other route's bus.)

### 8. Safety: SOS and trip link (both phones and laptop, 1 min)

- Phone B: **Share my trip** → **Share** opens WhatsApp/SMS with a link a
  parent can open to follow the bus.
- Phone A: tap **SOS** → **Send SOS**.
- Laptop: a red **SOS** banner and pop-up with a repeating alarm. Open
  **Safety alerts** and **Acknowledge** it.

### 9. The office dashboard (laptop, 1 min)

- **Live map**: all buses, summary cards.
- **Reports**: punctuality, ridership, bookings (two weeks of sample data).
- **Bus passes**, **Public transport**, **Drivers**, **Announcements**.

### 10. Close (30 s)

- Toggle **தமிழ்** on a phone: the whole app switches to Tamil.
- "Next: a pilot on one real route with the transport office's stops."

## If something goes wrong

| What you see | Do this |
| --- | --- |
| A phone says "Something went wrong" or "No connection" | Check its cable; replug, choose File transfer, wait up to a minute. |
| "This driver ID isn't set up yet" | The demo data was wiped. Run `npm run seed`, then `npm run demo-ready`, sign in again. |
| The bus does not move | The driver phone needs **Demo drive** on *before* Start Trip. End the trip, turn it on, start again. |
| Scan pass or SOS takes long the first time | Run `npm run warm-functions` once before the talk. |
| No sound on the laptop | Click anywhere on the dashboard once; browsers block sound until the page is clicked. |
