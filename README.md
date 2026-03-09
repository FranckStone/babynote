# 宝宝笔记

宝宝笔记 is an iOS app for quickly recording pregnancy and newborn care events for a growing family.

## Product Goal

The app is designed for one-hand, low-friction input during a busy day. It focuses on:

- feeding logs
- pregnancy weight tracking
- medication records
- exam and test results
- simple timeline review

## MVP Scope

### 1. Quick Log

Users can create records in a few taps:

- Feeding
  - start time
  - end time or duration
  - type: left breast, right breast, bottle, formula
  - amount
  - note
- Weight
  - date
  - body weight
  - note
- Medication
  - time
  - medicine name
  - dosage
  - note
- Checkup
  - date
  - hospital or clinic
  - result summary
  - attachment placeholder

### 2. Home Dashboard

The home screen should make the next action obvious:

- quick add buttons
- today summary
- latest feeding time
- latest weight
- upcoming checkup reminder placeholder

### 3. Timeline

A chronological list of all records:

- grouped by day
- filtered by type
- tap to edit

### 4. Statistics

Simple trends first:

- feeding frequency by day
- weight trend chart
- medication history

## Recommended Tech Stack

- SwiftUI for UI
- SwiftData for local persistence
- Charts for trend visualization
- UserNotifications for reminders

## Information Architecture

- Home
- Timeline
- Add Record
- Stats
- Settings

## Core Principles

- very fast input
- important information visible at a glance
- local-first
- easy to expand from pregnancy tracking into newborn care

## Suggested Milestones

1. Build data models and local storage
2. Build home screen and quick add flow
3. Build timeline and edit flow
4. Build charts and summary cards
5. Add reminders and export
