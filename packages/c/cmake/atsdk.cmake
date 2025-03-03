if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  FetchContent_Declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG 78a4e07665e5a2bdaa464476eb1c6ef4e1b3382a
  )
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
else()
  message(STATUS "atsdk already installed...")
endif()
