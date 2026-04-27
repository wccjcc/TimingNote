package com.timingnote.api;

import com.timingnote.api.infra.config.S3.S3Properties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@EnableConfigurationProperties(S3Properties.class)
@SpringBootApplication
public class TimingNoteApplication {

    public static void main(String[] args) {
        SpringApplication.run(TimingNoteApplication.class, args);
    }

}
