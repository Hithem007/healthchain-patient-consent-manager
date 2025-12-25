import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import consentRouter from "./routes/consent.js";

dotenv.config();

const app = express();
const port = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Existing mock data endpoints (placeholder) could be loaded here

// Mount the consent API at /api/consent
app.use("/api/consent", consentRouter);

app.get("/", (req, res) => {
  res.json({ status: "Consent API running" });
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
