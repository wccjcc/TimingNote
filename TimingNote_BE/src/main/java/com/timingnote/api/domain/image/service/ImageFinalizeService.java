package com.timingnote.api.domain.image.service;

import java.util.List;

public interface ImageFinalizeService {

    List<String> finalizeImageKeys(Long todoId, List<String> imageKeys);
}

