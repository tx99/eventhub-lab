package com.bookstore.controller;

import com.bookstore.controller.controller.AdminController;
import com.bookstore.controller.model.ServiceInfo;
import com.bookstore.controller.service.MessageService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
public class AdminControllerTest {

    @Autowired
    private AdminController adminController;

    @MockBean
    private MessageService messageService;

    @Test
    public void testRegisterService() {
        ServiceInfo serviceInfo = new ServiceInfo();
        serviceInfo.setName("test-service");
        serviceInfo.setUrl("http://test-service.com");

        adminController.registerService(serviceInfo);

        assertTrue(adminController.getRegisteredServices().containsKey("test-service"));
        assertEquals("http://test-service.com", adminController.getRegisteredServices().get("test-service").getUrl());
    }
}