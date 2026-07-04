# This is the project that summarizes my learning journey

From Docker, images created and containers run, 

To Kubernetes where the containers are easier to be deployed

To managed clusters by either GKE or AKS through GCP and Azure.

## Project structure

- The project consists of a setup for either of the cloud providers, GCP and Azure with a manual CLI approach and a Terraform approach
- The deployed workload is a tier 3 web application that has 2 APIs, 1 written in Go and the other in NodeJS, both querying a CNPG DB
- Alongside that, a Python Load Generator is deployed to repeatedly call a specified backend, either the api-golang or the api-node.
- There is also a React Frontend that displays the information regarding the backend/api called and the number of times it has been called.

## Deployment

## For Development Purposes

## CICD Github Actions ArgoCD
