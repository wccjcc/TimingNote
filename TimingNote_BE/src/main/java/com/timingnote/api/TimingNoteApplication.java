package com.timingnote.api;

import com.timingnote.api.infra.config.S3.S3Properties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@EnableConfigurationProperties(S3Properties.class)
@SpringBootApplication
public class TimingNoteApplication {

    public static void main(String[] args) {
        SpringApplication.run(TimingNoteApplication.class, args);
    }
}
