# BabyNote MVP Plan

## Target Users

- mother during pregnancy
- parents after birth
- family members helping with daily recording

## Main Use Cases

### Pregnancy Stage

- record body weight
- record medication
- record checkups and results
- review changes over time

### Newborn Stage

- quickly record feeding events
- review last feeding time
- identify daily patterns

## Data Model Draft

### FeedingRecord

- id
- startedAt
- endedAt
- feedingType
- amountML
- note

### WeightRecord

- id
- recordedAt
- weightKG
- note

### MedicationRecord

- id
- recordedAt
- name
- dosage
- note

### CheckupRecord

- id
- recordedAt
- location
- summary
- attachmentPath
- note

## Screen Draft

### Home

- Today summary card
- Last feeding card
- Pregnancy tracking shortcuts
- Quick add floating action area

### Add Record

- choose type first
- show short, focused form
- default time is now

### Timeline

- day sections
- mixed event feed
- filter chips

### Stats

- feeding count per day
- average interval between feeds
- weight trend

## Non-Goals For First Version

- multi-device sync
- account system
- AI analysis
- doctor collaboration
- complex report generation

## Phase 2 Ideas

- diaper log
- sleep log
- contractions tracking
- photo attachment for reports
- PDF export for doctor visits
- iCloud sync
