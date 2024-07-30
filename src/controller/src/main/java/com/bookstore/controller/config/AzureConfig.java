package com.bookstore.controller.config;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.messaging.eventhubs.EventHubClientBuilder;
import com.azure.messaging.eventhubs.EventHubProducerClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AzureConfig {

    @Value("${azure.keyvault.uri}")
    private String keyVaultUri;

    @Value("${azure.eventhub.namespace}")
    private String eventHubNamespace;

    @Value("${azure.eventhub.name}")
    private String eventHubName;

    @Bean
    public SecretClient secretClient() {
        return new SecretClientBuilder()
            .vaultUrl(keyVaultUri)
            .credential(new DefaultAzureCredentialBuilder().build())
            .buildClient();
    }

    @Bean
    public EventHubProducerClient eventHubProducerClient(SecretClient secretClient) {
        String connectionString = secretClient.getSecret("eventhub-connection-string").getValue();
        
        return new EventHubClientBuilder()
            .connectionString(connectionString, eventHubName)
            .buildProducerClient();
    }
}