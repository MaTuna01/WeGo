package com.tuna.wegobackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class WegoBackEndApplication {

    public static void main(String[] args) {
        SpringApplication.run(WegoBackEndApplication.class, args);
    }

}
