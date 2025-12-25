// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Patient Consent Manager
/// @notice Manages decentralized patient consent for healthcare data access
/// @dev Designed with auditability, gas efficiency and security in mind.  Each
///      patient owns their own consents and only they can approve or revoke
///      provider access.  Providers may request access which must be
///      explicitly approved by the patient.  Events emitted by this contract
///      allow off‑chain services to reconstruct the full consent history
///      without storing unbounded arrays on chain.  See the README for more
///      discussion on design choices.
contract PatientConsentManager {
    /*//////////////////////////////////////////////////////////////
                               DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Possible states of a consent between a patient and a provider
    enum ConsentStatus {
        NONE,       // no relationship exists
        REQUESTED,  // provider has requested access but patient has not yet approved
        ACTIVE,     // patient has granted access and it has not yet expired or been revoked
        REVOKED,    // patient has revoked an active consent
        EXPIRED     // consent duration elapsed without manual revocation
    }

    /// @notice Struct storing state and expiry for a consent
    struct Consent {
        ConsentStatus status;
        uint256 expiresAt; // UNIX timestamp; 0 if not applicable
    }

    /*//////////////////////////////////////////////////////////////
                             STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    // Mapping of patient => provider => consent
    mapping(address => mapping(address => Consent)) private consents;

    // Timestamps of all state changes for audit purposes
    mapping(address => mapping(address => uint256[])) private consentHistory;

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a provider requests access to a patient’s data
    event AccessRequested(address indexed patient, address indexed provider);

    /// @notice Emitted when a patient grants consent to a provider
    /// @param patient The patient granting consent
    /// @param provider The provider receiving consent
    /// @param expiresAt The timestamp at which the consent expires
    event ConsentGranted(address indexed patient, address indexed provider, uint256 expiresAt);

    /// @notice Emitted when a patient revokes consent
    event ConsentRevoked(address indexed patient, address indexed provider);

    /// @notice Emitted when a consent expires
    event ConsentExpired(address indexed patient, address indexed provider);

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Ensures that only the patient associated with a consent can call functions
    modifier onlyPatient(address patient) {
        require(msg.sender == patient, "PatientConsentManager: not patient");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by a provider to request access to a patient’s data.  The patient
    ///         must later call `grantConsent` to approve.  If a consent already exists
    ///         (requested, active or revoked), this call has no effect.
    /// @param patient The patient from whom access is requested
    function requestAccess(address patient) external {
        require(patient != address(0), "PatientConsentManager: invalid patient");
        Consent storage c = consents[patient][msg.sender];
        // Only allow requesting if no prior record exists
        if (c.status == ConsentStatus.NONE) {
            c.status = ConsentStatus.REQUESTED;
            consentHistory[patient][msg.sender].push(block.timestamp);
            emit AccessRequested(patient, msg.sender);
        }
    }

    /// @notice Called by the patient to approve an access request from a provider.  A
    ///         duration must be specified; the consent will expire automatically
    ///         after this period.  A previously revoked consent can also be re‑approved.
    /// @param provider The address of the provider whose request is being approved
    /// @param durationSeconds The number of seconds the consent should remain active
    function grantConsent(address provider, uint256 durationSeconds) external onlyPatient(msg.sender) {
        require(provider != address(0), "PatientConsentManager: invalid provider");
        require(durationSeconds > 0, "PatientConsentManager: zero duration");
        Consent storage c = consents[msg.sender][provider];
        // Only allow approval if a request was made or a previous consent was revoked/expired
        require(
            c.status == ConsentStatus.REQUESTED ||
            c.status == ConsentStatus.REVOKED ||
            c.status == ConsentStatus.EXPIRED,
            "PatientConsentManager: no pending request"
        );
        uint256 expiry = block.timestamp + durationSeconds;
        c.status = ConsentStatus.ACTIVE;
        c.expiresAt = expiry;
        consentHistory[msg.sender][provider].push(block.timestamp);
        emit ConsentGranted(msg.sender, provider, expiry);
    }

    /// @notice Called by the patient to revoke an active consent.  After revocation the
    ///         provider must request access again before approval is possible.
    /// @param provider The provider whose consent should be revoked
    function revokeConsent(address provider) external onlyPatient(msg.sender) {
        Consent storage c = consents[msg.sender][provider];
        require(c.status == ConsentStatus.ACTIVE, "PatientConsentManager: not active");
        c.status = ConsentStatus.REVOKED;
        c.expiresAt = 0;
        consentHistory[msg.sender][provider].push(block.timestamp);
        emit ConsentRevoked(msg.sender, provider);
    }

    /// @notice Batch approval of multiple providers.  Only providers with pending
    ///         requests or previously revoked/expired consents will be activated.
    /// @param providers Array of providers to approve
    /// @param durationSeconds Duration in seconds for all approvals
    function batchGrantConsent(address[] calldata providers, uint256 durationSeconds) external onlyPatient(msg.sender) {
        require(durationSeconds > 0, "PatientConsentManager: zero duration");
        uint256 expiry = block.timestamp + durationSeconds;
        for (uint256 i = 0; i < providers.length; i++) {
            address provider = providers[i];
            if (provider == address(0)) continue;
            Consent storage c = consents[msg.sender][provider];
            if (
                c.status == ConsentStatus.REQUESTED ||
                c.status == ConsentStatus.REVOKED ||
                c.status == ConsentStatus.EXPIRED
            ) {
                c.status = ConsentStatus.ACTIVE;
                c.expiresAt = expiry;
                consentHistory[msg.sender][provider].push(block.timestamp);
                emit ConsentGranted(msg.sender, provider, expiry);
            }
        }
    }

    /// @notice Retrieves the current consent status and expiry for a patient–provider pair.
    /// @param patient The patient address
    /// @param provider The provider address
    /// @return status The current status
    /// @return expiresAt The expiry timestamp (0 if not applicable)
    function getConsent(address patient, address provider) external view returns (ConsentStatus status, uint256 expiresAt) {
        Consent memory c = consents[patient][provider];
        // If the consent is active but expired, report status as EXPIRED
        if (c.status == ConsentStatus.ACTIVE && c.expiresAt > 0 && block.timestamp > c.expiresAt) {
            return (ConsentStatus.EXPIRED, c.expiresAt);
        }
        return (c.status, c.expiresAt);
    }

    /// @notice Returns all timestamps of state changes for a patient–provider pair
    /// @dev Off‑chain services can use the events and these timestamps to build a full audit log
    function getConsentHistory(address patient, address provider) external view returns (uint256[] memory) {
        return consentHistory[patient][provider];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL/PRIVATE LOGIC
    //////////////////////////////////////////////////////////////*/

    // Additional internal helpers could be added here if the logic grows
}
