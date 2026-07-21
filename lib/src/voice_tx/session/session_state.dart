/// Sender lifecycle states.
enum VoiceTxSenderState {
  idle,
  waitingForReady,
  sending,
  waitingForAcknowledgement,
  waitingForFinalResult,
  accepted,
  rejected,
  failed,
  completed
}

/// Receiver lifecycle states.
enum VoiceTxReceiverState {
  waitingForHello,
  receiving,
  validating,
  complete,
  rejected,
  failed
}
