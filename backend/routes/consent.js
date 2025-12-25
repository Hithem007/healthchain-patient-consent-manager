import express from "express";
import { getConsent, getConsentHistory } from "../web3/contractService.js";

const router = express.Router();

/**
 * GET /api/consent/status
 * Query parameters: patient, provider
 * Returns the current consent status and expiry timestamp.
 */
router.get("/status", async (req, res) => {
  const { patient, provider } = req.query;
  if (!patient || !provider) {
    return res.status(400).json({ error: "patient and provider are required" });
  }
  try {
    const [status, expiresAt] = await getConsent(patient, provider);
    res.json({ status: status.toString(), expiresAt: expiresAt.toString() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/consent/history
 * Query parameters: patient, provider
 * Returns an array of timestamps representing the on‑chain state change history.
 */
router.get("/history", async (req, res) => {
  const { patient, provider } = req.query;
  if (!patient || !provider) {
    return res.status(400).json({ error: "patient and provider are required" });
  }
  try {
    const history = await getConsentHistory(patient, provider);
    // Convert BigInts to strings for JSON compatibility
    const timestamps = history.map((t) => t.toString());
    res.json({ history: timestamps });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
