package com.bookstore.controller.config;

import com.azure.identity.DefaultAzureCredential;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.messaging.eventhubs.EventHubClientBuilder;
import com.azure.messaging.eventhubs.EventHubProducerClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.annotation.PostConstruct;


@Configuration
public class AzureConfig {

    private static final Logger logger = LoggerFactory.getLogger(AzureConfig.class);

    @Value("${azure.keyvault.uri}")
    private String keyVaultUri;

    @Value("${azure.eventhub.namespace}")
    private String eventHubNamespace;

    @Value("${azure.eventhub.name}")
    private String eventHubName;

    @Bean
    public SecretClient secretClient() {
        logger.info("Initializing SecretClient with Key Vault URI: {}", keyVaultUri);
        try {
            DefaultAzureCredential credential = new DefaultAzureCredentialBuilder().build();
            logger.info("DefaultAzureCredential built successfully");
            
            SecretClient client = new SecretClientBuilder()
                .vaultUrl(keyVaultUri)
                .credential(credential)
                .buildClient();
            logger.info("SecretClient initialized successfully");
            return client;
        } catch (Exception e) {
            logger.error("Error initializing SecretClient: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to initialize SecretClient", e);
        }
    }

    @Bean
    public EventHubProducerClient eventHubProducerClient(SecretClient secretClient) {
        logger.info("Initializing EventHubProducerClient for namespace: {} and hub: {}", 
                    eventHubNamespace, eventHubName);
        try {
            String secretName = "eventhub-connection-string";
            String connectionString = secretClient.getSecret(secretName).getValue();
            logger.info("Retrieved Event Hub connection string from Key Vault for secret: {}", secretName);
            
            EventHubProducerClient client = new EventHubClientBuilder()
                .connectionString(connectionString, eventHubName)
                .buildProducerClient();
            logger.info("EventHubProducerClient initialized successfully");
            return client;
        } catch (Exception e) {
            logger.error("Error initializing EventHubProducerClient: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to initialize EventHubProducerClient", e);
        }
    }

    @Bean
    public DefaultAzureCredential defaultAzureCredential() {
        logger.info("Building DefaultAzureCredential");
        try {
            DefaultAzureCredential credential = new DefaultAzureCredentialBuilder().build();
            logger.info("DefaultAzureCredential built successfully");
            return credential;
        } catch (Exception e) {
            logger.error("Error building DefaultAzureCredential: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to build DefaultAzureCredential", e);
        }
    }

    // Helper method to log environment variables
    private void logEnvironmentVariables() {
        logger.info("Environment Variables:");
        logger.info("AZURE_CLIENT_ID: {}", System.getenv("AZURE_CLIENT_ID"));
        logger.info("AZURE_TENANT_ID: {}", System.getenv("AZURE_TENANT_ID"));
        logger.info("AZURE_FEDERATED_TOKEN_FILE: {}", System.getenv("AZURE_FEDERATED_TOKEN_FILE"));
        logger.info("KEY_VAULT_URL: {}", System.getenv("KEY_VAULT_URL"));
        logger.info("AZURE_EVENTHUB_NAMESPACE: {}", System.getenv("AZURE_EVENTHUB_NAMESPACE"));
        logger.info("AZURE_EVENTHUB_NAME: {}", System.getenv("AZURE_EVENTHUB_NAME"));
    }

    
     @PostConstruct
     public void init() {
         logEnvironmentVariables();
     }
}
