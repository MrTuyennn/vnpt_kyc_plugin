/// Flutter plugin eKYC VNPT: quét CCCD, xác thực khuôn mặt 3D, OCR + liveness.
///
/// Chỉ những symbol dưới đây là public API; mọi thứ khác nằm trong `src/`.
library vnpt_kyc_plugin;

export 'src/api/ekyc_file_limits.dart' show ekycMaxImageBytes, isEkycFileTooLarge;
export 'src/api/ekyc_identity_verifier.dart'
    show EkycIdentityVerifier, IdentityStep, IdentityStepStatus;
export 'src/api/ekyc_session_init.dart' show EkycSessionInitRequest;
export 'src/api/ekyc_proxy_client.dart'
    show
        CardVerifyResult,
        EkycProxyClient,
        EkycProxyException,
        EkycProxySession,
        FaceCompareResult,
        FaceLivenessResult,
        FaceVerifyResult;
export 'src/core/ekyc_config.dart' show EkycConfig;
export 'src/core/ekyc_core.dart' show EkycCore;
export 'src/core/ekyc_session_artifacts.dart' show EkycSessionArtifacts;
export 'src/core/message_labels.dart' show messageResultLabel;
export 'src/core/pipeline_models.dart'
    show FullIdentityArtifactPaths, IdentityResult, PipelineResult;
export 'src/core/vnpt_identity_response.dart'
    show
        verifyVnptIdentity,
        vnptLivenessAccepted,
        vnptOcrAccepted,
        vnptResponseObject;
export 'src/flow/scan_results.dart'
    show CardScanResult, FaceScanResult, VnptCardSide;
export 'src/flow/vnpt_ekyc.dart' show VnptEkyc;
export 'src/l10n/ekyc_messages.dart' show EkycMessages;
export 'src/l10n/ekyc_strings.dart' show EkycStrings;
export 'src/platform/message_result.dart' show MessageResult;
export 'src/ui/ekyc_card_scanner.dart' show EkycCardScanner;
export 'src/ui/ekyc_oval_scanner.dart' show EkycOvalScanner;
