

# 🚀 Cost-effective GCP Compute Engine with Serverless Functions 🚀

This project sets up an intelligent, cost-effective infrastructure in Google Cloud Platform (GCP) to manage a Very Heavy Compute Engine instance (like ML instance with big GPU). The setup includes Cloud Functions to automatically start and stop the instance based on incoming traffic, log traffic details in Firestore, and periodically clean up the logs.

## Project Structure

```
.
├── configure_ttl.sh
├── functions
│   ├── clean_up
│   │   ├── index.js
│   │   └── package.json
│   ├── clean_up.zip
│   ├── proxy
│   │   ├── index.js
│   │   └── package.json
│   ├── proxy.zip
│   ├── shutdown
│   │   ├── index.js
│   │   └── package.json
│   └──  shutdown.zip
├── main.tf
└── zip_fonction.sh
```

## Setup Instructions

### Prerequisites

- Ensure you have the following tools installed:
  - [Terraform](https://www.terraform.io/downloads.html)
  - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- Configure your GCP credentials:
  ```bash
  gcloud auth application-default login
  ```

### Step-by-Step Setup

1. **Clone the Repository**

   Clone this repository to your local machine:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Zip the Function Directories**

   Run the `zip_fonction.sh` script to zip the Cloud Function directories:
   ```bash
   sh zip_fonction.sh
   ```

3. **Initialize Terraform**

   Initialize the Terraform configuration:
   ```bash
   terraform init
   ```

4. **Apply the Terraform Configuration**

   Apply the Terraform configuration to create and configure the necessary GCP resources:
   ```bash
   terraform apply
   ```

   Confirm the apply by typing `yes` when prompted.

### Project Components

- **`functions/`**:
  - Contains the source code for the Cloud Functions.
  - **`proxy/`**: Starts the instance if it is stopped and logs incoming traffic.
  - **`shutdown/`**: Stops the instance if there is no incoming traffic for a defined idle period.
  - **`clean_up/`**: Cleans up Firestore logs after a specified duration.

- **`main.tf`**:
  - The main Terraform configuration file defining the infrastructure setup.

- **`configure_ttl.sh`**: (Does not work yet)
  - A script to configure TTL settings in Firestore.

- **`zip_fonction.sh`**:
  - A script to zip the Cloud Function directories for deployment.

### Enable Required Google APIs

Make sure to enable the following Google APIs manually in your GCP project:

1. Cloud Functions API
2. Firestore API
3. Cloud Scheduler API
4. Compute Engine API
5. Cloud Logging API
6. VPC Access API
7. IAM API
8. Cloud Storage API

You can enable these APIs via the GCP Console or by using the `gcloud` command-line tool:
```bash
gcloud services enable cloudfunctions.googleapis.com \
                        firestore.googleapis.com \
                        cloudscheduler.googleapis.com \
                        compute.googleapis.com \
                        logging.googleapis.com \
                        vpcaccess.googleapis.com \
                        iam.googleapis.com \
                        storage.googleapis.com
```

### Environment Variables

Make sure to configure the following environment variables in your `.env` file or export them in your shell:

- `GOOGLE_CLOUD_PROJECT`: Your GCP project ID.
- `GCP_REGION`: The GCP region for deployment.
- `GCP_ZONE`: The GCP zone for deployment.

### Monitoring and Maintenance

- **Logs**: Monitor logs in the GCP Console to track the execution of Cloud Functions and the state of the Compute Engine instance.
- **Firestore**: Check Firestore for logs of incoming traffic and TTL configurations.
- **Scheduler**: Ensure the Cloud Scheduler job is running periodically to clean up old logs.

### Troubleshooting

- If any issues arise during Terraform apply, check the error messages and ensure all GCP services and permissions are correctly configured.
- Verify that all zipping steps are completed successfully before applying Terraform.
- Ensure your GCP credentials are correctly set up and have the necessary permissions.


## To-Do

- **Make Traffic Passing to the NAT Gateway Internal Only**: Configure the network settings to ensure that traffic passing through the NAT gateway is restricted to internal traffic only for enhanced security.
- **Add API Key Management with Firestore**: Implement API key management using Firestore to securely manage and validate API keys for accessing the proxy 

## Contributing

Contributions are welcome! Please follow the standard GitHub workflow:

1. Fork the repository.
2. Create a new branch.
3. Make your changes.
4. Submit a pull request.

## License

This project is licensed under the MIT License.







