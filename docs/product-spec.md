# LEV — Product Specification

> Product specification: **what** LEV is and **for whom**. For **how** to build it, see the Technical Specification (`docs/technical-spec.md`).

---

## 1. Vision
To lead a change in digital consumption culture, and to build a world where technology serves people and community rather than the other way around. LEV aims to be the leading digital home for positive connection and mutual aid, while fully preserving its users' independence, trustworthiness, and peace of mind.

## 2. Project Description
LEV is an independent technology platform, born from the aspiration to harness the power of digital tools to positively influence the world.

In a world where media and technology are sometimes driven by interests that generate information overload, tension, and instability, LEV chooses to use technology for the opposite purpose: creating a space that surfaces the good, encourages a positive outlook, and enables mutual help. The application operates entirely independently of external interested parties, to ensure this positive impact stays clean, safe, and authentic.

It does this through two core capabilities:

1. **Supportive chat** — the user holds a free-form conversation with an assistant powered by a **local language model**. The assistant identifies, over the course of the conversation, the user's pattern/archetype and calibrates its responses accordingly. The response is designed to be calming, stabilizing, and encouraging: it filters noise, focuses on what matters, and reflects reality without distorted thinking — helping the user see things in proportion and respond from a place of clarity.
2. **Mutual aid** — the user can request help and also view nearby help requests.

## 3. Target Audience
- Users seeking a calming, supportive, and private space for conversation, free from exposure to external parties.
- People who want to lend a hand or receive community help in their immediate surroundings.

## 4. Languages
- English
- Hebrew

## 5. User Actions
- **Conversation & chat:** messaging with LEV — a supportive, personalized chat powered by a local language model.
- **Managing help requests (the user's own):**
  - Add a new help request.
  - Edit an existing help request.
  - Delete a help request.
- **Managing mutual-aid tasks:**
  - View others' nearby help requests.
  - Commit to performing a help task.
  - Cancel a commitment.
  - Mark a help task as completed.

## 6. Application Screens & User Flow

### Home Screen
- The application's main screen; presents a brief summary of LEV's purpose.
- Components and actions:
  - Quick-navigation button to the chat conversation.
  - Quick-navigation button to the help-tasks screen.

### Chat Screen
- A continuous conversation area with the local language model.
- Components and actions:
  - A prompt/message input field.
  - A display window for messages and the local model's responses.

### Tasks Screen
- A list view of nearby help tasks and requests.
- Components and actions:
  - Top button: "Add new request" (opens a window to enter the request details).
  - Advanced filtering options (by my requests / requests I committed to / etc.).
  - Tapping a request the user posted: opens a window with edit and delete options.
  - Tapping another user's request: opens a window with a "take the task" option.
  - Tapping a request the user already took on: an option to mark "completed" or "cancel taking the task".

## 7. Non-Functional Requirements & Constraints
- **Offline-first:** the application operates without an internet connection.
- **Technological independence:** no dependency on a central server, on the cloud, or on external registration/authentication mechanisms.
- **Local communication:** transferring tasks between nearby users is done via local communication technology (P2P / Mesh).
- **Privacy & security:** data is stored encrypted on the local device only; there is no collection of or tracking of user identity.
- **Performance:** the local model is optimized for efficient execution while keeping memory and battery consumption optimal.
