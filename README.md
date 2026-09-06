# 💧 AquaShare

### Community Groundwater Pump Booking & Water Tracking

AquaShare is a simple mobile-first web app for rural farming communities that share groundwater pumps.

It helps farmers book pump slots, keep track of water usage, see the pump schedule, and report problems — all from a phone without installing an app.

**Live Demo:** https://aquashare.vercel.app

**Built by:** Dhruv | SVIT, Hyderabad

---

## The Problem

In many rural areas, farmers share a limited number of community tube wells and pumps. During summer, water becomes scarce and everyone needs access to the same pumps.

Without a proper scheduling system, a few common problems happen:

* Two farmers may arrive at the same pump at the same time.
* Some farmers may use more than their fair share of water.
* Broken pumps and missed slots may not get reported.
* There is no clear record when disagreements happen.

This can lead to wasted water, damaged crops, and unnecessary conflicts within the community.

---

## The Solution

AquaShare provides one shared place where farmers can manage pump usage.

The current version supports **30 farmers and 5 community pumps**.

Farmers can:

* Book a 2-hour pumping slot.
* Check the schedule for each pump.
* See upcoming, active, and completed bookings.
* Enter start and end meter readings.
* Automatically calculate the amount of water used.
* Report broken pumps.
* Report schedule overruns.
* Get notified when the community's daily water limit is reached.

The app works directly in a browser and does not require an installation.

All farmers see the same data through Supabase in real time.

---

## Main Features

### Pump Booking

Farmers can select:

* Pump
* Date
* Available 2-hour time slot

Available slots run from **6 AM to 8 PM**.

Before a booking is confirmed, AquaShare checks the shared database to make sure the slot isn't already taken.

### Shared Schedule

Each pump has a simple timeline showing:

* Upcoming slots
* Active slots
* Completed slots
* Missed slots
* Interrupted bookings

This makes it easy to understand pump availability without having to ask someone else.

### Water Meter Tracking

Farmers enter their:

* Starting meter reading
* Ending meter reading

The app calculates the water used automatically:

```text
Water Used = End Reading - Start Reading
```

Farmers don't have to manually calculate or enter the amount of water consumed.

### Community Water Limit

The community has a daily extraction limit of **50,000 litres**.

When the limit is reached:

* New reservations are paused.
* The booking button is disabled.
* A warning is shown across the app.

Existing active bookings are not stopped.

### Pump Reports

Farmers can quickly report:

* Broken pumps
* Schedule overruns

If a pump is reported broken while someone is using it, everyone receives a warning and the booking is marked as interrupted.

---

# Why Supabase?

The project brief requires **zero paid APIs** and does not expect a traditional paid backend.

Supabase's free tier gives AquaShare a shared PostgreSQL database and realtime functionality without requiring a paid server.

More importantly, AquaShare needs something that `localStorage` simply cannot provide: **shared state between different phones.**

### The Problem With localStorage

`localStorage` belongs to a specific browser on a specific device.

For example:

> Farmer A books Pump 3 at 10 AM on their phone.

If AquaShare only used `localStorage`, Farmer B using a different phone would not know about that booking.

The schedule would be different on every device, which makes community-wide coordination impossible.

It also means conflict prevention would only work locally. Two farmers could potentially book the same pump because neither phone knows what the other phone has already booked.

That defeats the main purpose of AquaShare.

---

## Why Supabase Instead of Other Options?

| Option                | Why it wasn't used                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **localStorage only** | Data is stored per device, so there is no shared state or reliable cross-device conflict prevention.                     |
| **Firebase**          | Adds more complexity for this project, and its pricing/free-tier model was less suitable for the intended setup.         |
| **PocketBase**        | Requires a server to host, which adds infrastructure and deployment requirements.                                        |
| **Airtable API**      | Not a good fit for a realtime shared booking system and has API/rate-limit considerations.                               |
| **Google Sheets API** | Requires OAuth and is not designed for this kind of anonymous community access.                                          |
| **Supabase**          | PostgreSQL database, realtime updates, browser SDK, and serverless-friendly deployment make it a good fit for AquaShare. |

---

## What Supabase Makes Possible

### 1. Real Conflict Prevention

The booking check happens against the shared database instead of a local JavaScript array.

When a farmer tries to book a slot, AquaShare checks whether another booking exists for:

* The same pump
* The same date
* An overlapping time period

The overlap check is:

```text
existing_start < new_end
AND
existing_end > new_start
```

If there is a conflict, the new booking is rejected.

This means two farmers using two different phones cannot simply have two independent versions of the schedule.

---

### 2. Real-Time Schedule Updates

AquaShare uses **Supabase Realtime** to push database changes to connected devices.

For example:

```text
Farmer A books Pump 2
        ↓
Supabase database updates
        ↓
Realtime event is sent
        ↓
Farmer B's phone updates
```

There is no need for the farmer to refresh the page manually.

---

### 3. Community-Wide Water Totals

Water usage is stored in the shared database.

This allows AquaShare to calculate the community's total extraction across different farmers and devices.

The **50,000 L daily limit** therefore isn't based on what one phone knows about. It is based on the shared water records.

---

### 4. Broken Pump Updates

If someone reports a pump as broken, the change is stored centrally.

Other connected devices receive the update and show the pump as unavailable.

This prevents one farmer from continuing to book a pump that another farmer has already reported as broken.

---

# Supabase Security

The Supabase **anon key is intentionally included in the frontend**.

This is how Supabase's browser-based architecture is designed to work. The public anon key is different from the **service role key**.

AquaShare only uses the anon key in `index.html`.

The service role key is never placed in the frontend.

Access to the database is controlled through Supabase's table policies and row-level access rules rather than by trying to hide the public anon key.

In other words, the key being visible in the browser does not give the frontend full administrator access.

---

# Offline Resilience

Rural areas can have unreliable internet connections, especially when using mobile data or 2G networks.

AquaShare therefore has a local fallback.

If Supabase becomes temporarily unreachable:

1. The app continues using local storage where possible.
2. Changes are queued locally.
3. Once connectivity returns, the app can synchronize the queued changes.

This allows the application to remain usable even when the connection isn't perfect.

---

# Preventing Double Bookings

When a farmer selects a pump, date, and time slot and presses **Confirm**, AquaShare checks Supabase for an existing booking.

A conflict occurs when:

* The pump is the same.
* The date is the same.
* The requested time overlaps an existing booking.

If another booking already exists, the reservation is rejected and the user gets a clear message:

> ⛔ This slot is unavailable. Pump 2 is already reserved from 10:00 AM to 12:00 PM. Please choose a different time.

The schedule itself does not need to expose unnecessary information about other farmers.

The important information for the user is simply that the requested slot is unavailable.

---

# Handling Edge Cases

### Missed Bookings

If a booking starts but no meter reading is recorded, the booking is marked as **MISSED**.

The farmer is also reminded to enter the meter reading.

### Large Water Usage

If a single session exceeds **8,000 litres**, the app asks the farmer to confirm the reading.

The reading can still be saved, but it is flagged so unusually high usage is visible in the water log.

### Pump Failure

If a pump is reported broken during an active booking:

* A warning appears for everyone.
* The booking is marked as **Interrupted**.
* The farmer is asked to record the meter reading.

### Daily Limit

Once total community extraction reaches **50,000 litres**, new bookings are paused.

The booking button changes to:

```text
Daily limit reached — booking paused
```

Existing active bookings are not interrupted.

### Simultaneous Booking Attempts

Because bookings are checked against shared Supabase data, AquaShare does not rely only on each individual phone's local state.

If two farmers attempt to reserve the same slot at nearly the same time, the conflicting booking is rejected rather than allowing both devices to maintain separate schedules.

---

# Data Validation

AquaShare validates meter readings before saving them.

* The end meter reading must be greater than the start reading.
* Water usage is calculated automatically.
* Zero or negative usage cannot be saved.
* Meter values must be positive numbers.
* Non-numeric values are rejected.
* Sessions above 8,000 L require confirmation before being saved.

This reduces the amount of manual calculation required from the farmer and prevents common input mistakes.

---

# Designed for Rural Users

The interface is intentionally simple.

Some of the design choices include:

* Mobile layout optimized for screens up to around **420px** wide.
* Large buttons with at least **48px** tap targets.
* Three main tabs:

  * Book
  * Schedule
  * Report
* Simple language instead of technical terms.
* High-contrast colors for better visibility outdoors.
* No app installation.
* No account creation or password required.

The idea is simple: a farmer should be able to open the website and understand what to do without needing a tutorial.

---

# Architecture & Design Decisions

### Single HTML File

The entire application currently lives inside one `index.html` file.

For a large production application, separating the frontend into components and modules would make more sense.

For this project, however, keeping everything in one file makes it:

* Easy to deploy.
* Easy to inspect.
* Easy to modify.
* Free from a build process.

For a short hackathon build, this was a practical trade-off.

### No Login System

Farmers enter their name when making a booking instead of creating an account.

This removes:

* Passwords
* Email verification
* Account creation
* Login screens

The idea is to keep the application usable for people who may not already have online accounts.

### Web App Instead of Native Android App

AquaShare works directly in a mobile browser.

Farmers can open the application using a URL or QR code without downloading anything from an app store.

This also makes deployment and updates much simpler.

### Realtime Instead of Polling

Instead of asking the database for updates every few seconds, AquaShare uses Supabase Realtime.

This reduces unnecessary requests while allowing connected devices to receive changes as they happen.

### Fixed Daily Limit

The **50,000 litre** daily limit is currently defined in the application.

Keeping it fixed prevents accidental changes to the safety threshold through the UI.

A future version could move this value into an admin configuration.

---

# Tech Stack

* **Frontend:** HTML, CSS, Vanilla JavaScript
* **Database:** Supabase / PostgreSQL
* **Realtime:** Supabase Realtime
* **Hosting:** Vercel
* **Repository:** GitHub
* **Build system:** None
* **Paid APIs:** None
* **Native dependencies:** None

---

# Database

AquaShare currently uses three main tables in Supabase:

```text
bookings
- pump_id
- farmer_name
- date
- slot_start
- slot_end
- status
- meter readings

reports
- pump_id
- reporter_name
- report_type
- resolved

water_log
- booking_id
- water_drawn
- flagged
- date
```

---

# Running Locally

There is no build process required.

Clone the repository:

```bash
git clone https://github.com/Dhruvv14569/Aquashare
```

Then open:

```text
index.html
```

in a browser.

On the first load, provide your Supabase Project URL and Anon Key.

That's it.

---

# Project Status

AquaShare is currently a hackathon project demonstrating the core booking, scheduling, water tracking, reporting, realtime synchronization, and safety features.

Possible future improvements include:

* Admin dashboard
* Configurable water limits
* Farmer accounts
* Better offline synchronization
* Usage history and analytics
* Telugu and other regional language support
* Pump maintenance history
* Community usage reports
* More detailed water consumption analytics

---

# License

This project was built as part of the AquaShare Hackathon Challenge.

---

**Built for the AquaShare Hackathon Challenge · September 2026**
