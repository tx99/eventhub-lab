package com.bookstore.controller.service;

import com.azure.messaging.eventhubs.EventData;
import com.azure.messaging.eventhubs.EventHubProducerClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.Map;
import java.util.Collections; // Add this import

@Service
public class MessageService {

    private final EventHubProducerClient eventHubProducerClient;
    private boolean useEventHub = false;

    @Autowired
    public MessageService(EventHubProducerClient eventHubProducerClient) {
        this.eventHubProducerClient = eventHubProducerClient;
    }

    public void updateSettings(Map<String, Object> settings) {
        if (settings.containsKey("useEventHub")) {
            useEventHub = (boolean) settings.get("useEventHub");
        }
        // Handle other settings
    }

    public void sendMessage(String message) {
        if (useEventHub) {
            sendMessageViaEventHub(message);
        } else {
            sendMessageViaRestApi(message);
        }
    }

    private void sendMessageViaEventHub(String message) {
        EventData eventData = new EventData(message);
        eventHubProducerClient.send(Collections.singletonList(eventData));
    }

    private void sendMessageViaRestApi(String message) {
        // code to send message via REST API to registered services
        System.out.println("Sending message via REST API: " + message);
    }
}
