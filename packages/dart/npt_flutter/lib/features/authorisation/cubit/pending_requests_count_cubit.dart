import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingRequestsCountCubit extends Cubit<int> {
  PendingRequestsCountCubit(this._authorisationService) : super(0) {
    // Update the count whenever a new request is made
    _subscription = _authorisationService.enrollmentRequests().listen((_) => getPendingRequests());
    getPendingRequests();
  }

  final AuthorisationService _authorisationService;
  StreamSubscription<ServerEnrollmentRequest>? _subscription;

  Future<void> getPendingRequests() async {
    final requests = await _authorisationService.getEnrollmentRequests(
      statusFilters: [EnrollmentStatus.pending],
    );
    emit(requests.length);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
