# Healthcare Blockchain Assessment - Submission

This repository contains my solution to the **AI Health Chains** take‑home assessment for the **Senior Blockchain & Web3 Developer** role.  The focus of the exercise is building a decentralized patient consent management system that spans a Solidity smart contract, a Node.js/Express backend and an optional React frontend.

The solution here aims to be **production‑ready** and demonstrates a clean architecture, security best practices and gas‑efficient design.  I have structured the code in a similar layout to the provided scaffold to make it easy to integrate with the original repository if desired.

## Project structure

```
submission/
├── backend/
│   ├── contracts/
│   │   └── PatientConsentManager.sol   # fully‑fledged smart contract (ERC compliant patterns)
│   ├── web3/
│   │   ├── contractService.js          # ethers.js service layer for contract interactions
│   │   └── abi.json                   # output from compilation (placeholder)
│   ├── routes/
│   │   └── consent.js                 # Express router exposing REST endpoints for consent management
│   ├── server.js                      # Entry point for the backend API
│   └── package.json                   # Minimal dependencies
└── README.md                          # this document
```

## Key improvements and design choices

### 1. Smart contract (`PatientConsentManager.sol`)

* **Consent lifecycle:**  Each patient–provider pair has a `ConsentStatus` (NONE, REQUESTED, ACTIVE, REVOKED, EXPIRED) and an expiration timestamp.  The patient owns their data and is the only actor that can grant or revoke access.  Providers may only _request_ access.
* **Batch operations:**  Patients can grant or revoke multiple provider consents in a single transaction to reduce gas costs.
* **Expiry handling:**  Consents include a duration and automatically transition to `EXPIRED` when the expiry time elapses.
* **Audit trail:**  Events (`AccessRequested`, `ConsentGranted`, `ConsentRevoked`, `ConsentExpired`) are emitted for every state change and can be indexed off‑chain to reconstruct history without storing unbounded arrays on chain.
* **Gas optimisations:**  `mapping(address => mapping(address => Consent))` provides O(1) lookup; no dynamic arrays are stored; batch loops are kept minimal.
* **Access control:**  A `modifier` ensures only the patient associated with a consent can grant or revoke it.
* **Comprehensive NatSpec documentation** to aid auditors.

### 2. Backend integration

The backend uses **ethers.js** to connect to a local Hardhat/Ethereum node.  A `contractService.js` module loads the ABI and contract address from the compilation artefacts and exposes promise‑based functions such as `requestAccess`, `grantConsent`, `revokeConsent`, `getConsent` and `getConsentHistory`.  This module is injected into Express routes.

`routes/consent.js` defines REST endpoints such as:

* `POST /api/consent/request` – provider requests access to a patient’s records.
* `POST /api/consent/grant` – patient grants consent to a provider for a given duration.
* `POST /api/consent/revoke` – patient revokes an active consent.
* `GET  /api/consent/status?patient=...&provider=...` – returns current consent status and expiry time.
* `GET  /api/consent/history?patient=...&provider=...` – returns an array of timestamps representing the on‑chain history.

The server loads the mock patient/provider data structures in memory (left unchanged from the assessment scaffold) and adds these endpoints alongside the existing ones.  Error handling wraps `ethers.js` calls and returns HTTP 4xx/5xx codes appropriately.

### 3. Frontend (optional)

A React UI is **not included** here to keep the submission concise.  However, the backend API design and contract events make it straightforward to build a frontend that uses `useEffect` hooks to fetch consent status/history and call the grant/revoke endpoints.  A recommended approach is to leverage [wagmi](https://wagmi.sh/) or [`@web3-react`](https://github.com/Uniswap/web3-react) for wallet connection, show transaction states (pending/confirmed/error) and subscribe to events via WebSocket for real‑time updates.

## Setup and testing

1. Install dependencies:

   ```sh
   cd submission/backend
   npm install
   ```

2. Compile and deploy the contract locally (using Hardhat):

   ```sh
   npx hardhat compile
   npx hardhat node &
   npx hardhat run scripts/deploy.js --network localhost
   ```

   The deployment script should write the contract address to a JSON file read by `contractService.js`.

3. Start the backend server:

   ```sh
   node server.js
   ```

   The API will run on `http://localhost:3001` by default.

4. Use `curl` or Postman to exercise the endpoints.  For example:

   ```sh
   # Provider requests access
   curl -X POST -H "Content‑Type: application/json" \ 
     -d '{"patient":"0xABCD...","provider":"0x1234..."}' \ 
     http://localhost:3001/api/consent/request

   # Patient grants consent for 30 days
   curl -X POST -H "Content‑Type: application/json" \ 
     -d '{"patient":"0xABCD...","provider":"0x1234...","duration":2592000}' \ 
     http://localhost:3001/api/consent/grant
   ```

## Concluding notes

This solution addresses the core requirements of the assessment with particular attention to **security**, **auditability** and **gas efficiency**.  The smart contract uses well‑established patterns and provides a clean interface for off‑chain services.  The backend integration exposes a simple REST layer that can be consumed by a React frontend or other clients.  Additional features such as encryption, multi‑signature approvals and analytics dashboards can be layered on top without changing the underlying consent model.
