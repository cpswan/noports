if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  FetchContent_Declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG df5d75ab917e1f290862adf92af141f6754fe4b1
  )
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
else()
  message(STATUS "atsdk already installed...")
endif()
