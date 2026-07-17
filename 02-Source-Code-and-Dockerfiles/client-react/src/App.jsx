import { useState } from "react";
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
} from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import axios from "axios";

import "./App.css";

const queryClient = new QueryClient();

const SERVICES = [
  {
    id: "golang",
    api: "/api/golang/",
    label: "Go API",
    language: "Go (Gin)",
    description:
      "Written in Go with Gin. Talks to the shared PostgreSQL cluster via CloudNativePG and exposes /metrics for Prometheus scraping.",
  },
  {
    id: "node",
    api: "/api/node/",
    label: "Node.js API",
    language: "Node.js (Express)",
    description:
      "Written in Node.js with Express. Shares the same Postgres cluster as the Go service and also sexposes /metrics for Prometheus scraping.",
  },
];

function CurrentTime({ service }) {
  const { isLoading, error, data, isFetching } = useQuery({
    queryKey: [service.api],
    queryFn: () => axios.get(service.api).then((res) => res.data),
  });

  return (
    <div className="service-card">
      <h3>{service.label}</h3>
      <p className="service-description">{service.description}</p>
      <p className="service-endpoint">
        <code>{service.api}</code>
      </p>

      {isLoading && <p>Loading {service.api}...</p>}
      {error && (
        <p className="error">An error has occurred: {error.message}</p>
      )}

      {data && (
        <div className="service-data">
          <p>API: {data.api}</p>
          <p>Time from DB: {data.currentTime}</p>
          <p>Request Count: {data.requestCount}</p>
          <div className="fetch-status">{isFetching ? "Updating..." : ""}</div>
        </div>
      )}
    </div>
  );
}

function NavBar({ activeView, onSelect }) {
  return (
    <nav className="nav-bar">
      <button
        className={activeView === "all" ? "active" : ""}
        onClick={() => onSelect("all")}
      >
        Overview
      </button>
      {SERVICES.map((service) => (
        <button
          key={service.id}
          className={activeView === service.id ? "active" : ""}
          onClick={() => onSelect(service.id)}
        >
          {service.label}
        </button>
      ))}
    </nav>
  );
}

export function App() {
  const [activeView, setActiveView] = useState("all");

  const visibleServices =
    activeView === "all"
      ? SERVICES
      : SERVICES.filter((s) => s.id === activeView);

  return (
    <QueryClientProvider client={queryClient}>
      <div className="App">
        <header className="app-header">
          <h1>DevOps Portfolio Project</h1>
          <p>
            A 3-tier cloud-native app running on GKE, tied
            together with ArgoCD, Traefik, and CloudNativePG. Both APIs below
            sit behind the same ingress path prefix, which Traefik's
            middleware strips before the request reaches either backend.
          </p>
        </header>

        <NavBar activeView={activeView} onSelect={setActiveView} />

        <main className="service-grid">
          {visibleServices.map((service) => (
            <CurrentTime key={service.id} service={service} />
          ))}
        </main>
      </div>
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}

export default App;