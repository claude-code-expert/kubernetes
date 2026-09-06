package com.example.k8ssampleboot.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
public class IndexController {

    private final Environment environment;

    public IndexController(Environment environment) {
        this.environment = environment;
    }

    @GetMapping("/hello")
    public String getHello() {
        String helloWorld = "Hello World! V3";
        String host = environment.getProperty("HOSTNAME");
        log.info("##### getHello V3 = {} and Host = {}", helloWorld, host);
        return helloWorld + " (Host = " + host + ")";
    }
}
