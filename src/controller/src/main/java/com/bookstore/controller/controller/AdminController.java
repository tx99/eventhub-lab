package com.bookstore.controller.controller;

import com.bookstore.controller.model.ServiceInfo;
import com.bookstore.controller.service.MessageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.ResponseEntity;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private static final Logger logger = LoggerFactory.getLogger(AdminController.class);

    private final Map<String, ServiceInfo> registeredServices = new ConcurrentHashMap<>();
    private final MessageService messageService;
    private final RestTemplate restTemplate;

    @Autowired
    public AdminController(MessageService messageService, RestTemplate restTemplate) {
        this.messageService = messageService;
        this.restTemplate = restTemplate;
        logger.info("AdminController initialized");
    }

    @PostMapping("/register")
    public ResponseEntity<String> registerService(@RequestBody ServiceInfo serviceInfo) {
        logger.info("Registering service: {}", serviceInfo.getName());
        registeredServices.put(serviceInfo.getName(), serviceInfo);
        logger.info("Service registered successfully: {}", serviceInfo.getName());
        return ResponseEntity.ok("Service registered successfully");
    }

    @PostMapping("/settings")
    public ResponseEntity<String> updateSettings(@RequestBody Map<String, Object> settings) {
        logger.info("Updating settings: {}", settings);
        messageService.updateSettings(settings);
        logger.info("Settings updated successfully");
        return ResponseEntity.ok("Settings updated successfully");
    }

    @GetMapping("/services")
    public ResponseEntity<Map<String, ServiceInfo>> getRegisteredServices() {
        logger.info("Fetching registered services");
        return ResponseEntity.ok(registeredServices);
    }

    @PostMapping("/message")
    public ResponseEntity<String> sendMessage(@RequestBody String message) {
        logger.info("Received message to send: {}", message);
        messageService.sendMessage(message);
        logger.info("Message sent via MessageService");
        
        // Send the message to all registered services
        for (ServiceInfo service : registeredServices.values()) {
            try {
                logger.info("Sending message to service: {}", service.getName());
                String url = service.getUrl() + "/receive-message";
                ResponseEntity<String> response = restTemplate.postForEntity(url, message, String.class);
                if (response.getStatusCode().is2xxSuccessful()) {
                    logger.info("Message sent successfully to service: {}", service.getName());
                } else {
                    logger.warn("Failed to send message to service: {}. Status: {}", service.getName(), response.getStatusCode());
                }
            } catch (Exception e) {
                logger.error("Error sending message to {}: {}", service.getName(), e.getMessage());
            }
        }
        return ResponseEntity.ok("Message sent to all registered services");
    }

    @PostMapping("/receive-message")
    public ResponseEntity<String> receiveMessage(@RequestBody String message) {
        logger.info("Controller received message: {}", message);
        // Process the message
        return ResponseEntity.ok("Message received by controller");
    }
}