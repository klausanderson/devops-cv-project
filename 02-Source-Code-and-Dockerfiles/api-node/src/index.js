const { getDateTimeAndRequests, insertRequest } = require("./db");

const express = require("express");
const morgan = require("morgan");
const client = require("prom-client");   // <- added for Prometheus

const app = express();
const port = process.env.PORT || 3000;

// Prometheus default metrics (process CPU, memory, event loop lag, etc.)
const register = client.register;
client.collectDefaultMetrics({ register });   // <- added for Prometheus

// setup the logger
app.use(morgan("tiny"));

app.get("/", async (req, res) => {
  await insertRequest();
  const response = await getDateTimeAndRequests();
  console.log = response;
  response.api = "node";
  res.send(response);
});

app.get("/ping", async (_, res) => {
  res.send("pong");
});

app.get("/metrics", async (_, res) => {   // <- added for Prometheus
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

const server = app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});

process.on("SIGTERM", () => {
  console.debug("SIGTERM signal received: closing HTTP server");
  server.close(() => {
    console.debug("HTTP server closed");
  });
});
