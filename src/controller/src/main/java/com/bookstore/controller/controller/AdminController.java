package com.bookstore.controller.controller;

import com.bookstore.controller.model.ServiceInfo;
import com.bookstore.controller.service.MessageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final Map<String, ServiceInfo> registeredServices = new ConcurrentHashMap<>();
    private final MessageService messageService;

    @Autowired
    public AdminController(MessageService messageService) {
        this.messageService = messageService;
    }

    @PostMapping("/register")
    public void registerService(@RequestBody ServiceInfo serviceInfo) {
        registeredServices.put(serviceInfo.getName(), serviceInfo);
    }

    @PostMapping("/settings")
    public void updateSettings(@RequestBody Map<String, Object> settings) {
        messageService.updateSettings(settings);
    }

    @GetMapping("/services")
    public Map<String, ServiceInfo> getRegisteredServices() {
        return registeredServices;
    }

    @PostMapping("/message")
    public void sendMessage(@RequestBody String message) {
        messageService.sendMessage(message);
    }
}