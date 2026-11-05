import 'package:flutter/material.dart';
import '../../providers/sip_provider.dart';
import '../../utils/constants.dart';

/// SIP 상태 바 위젯
/// 
/// SIP 등록 상태, 통화 상태, 네트워크 상태 등을 표시하는 위젯입니다.
class SipStatusBar extends StatelessWidget {
  /// SIP Provider
  final SipProvider sipProvider;
  
  /// 배경 색상
  final Color? backgroundColor;
  
  /// 텍스트 색상
  final Color? textColor;
  
  /// 패딩
  final EdgeInsetsGeometry? padding;
  
  /// 아이콘 크기
  final double iconSize;
  
  /// 텍스트 스타일
  final TextStyle? textStyle;
  
  /// 생성자
  const SipStatusBar({
    super.key,
    required this.sipProvider,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 등록 상태 아이콘
          _buildStatusIcon(sipProvider),
          const SizedBox(width: AppConstants.spacingSm),
          
          // 등록 상태 텍스트
          Expanded(
            child: Text(
              sipProvider.getRegistrationStatusText(),
              style: textStyle ?? TextStyle(
                color: textColor ?? _getStatusColor(sipProvider),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 통화 상태 (통화 중일 때만 표시)
          if (sipProvider.isInCall) ...[
            const SizedBox(width: AppConstants.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingSm,
                vertical: AppConstants.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call_outlined,
                    color: Colors.green,
                    size: iconSize,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text(
                    sipProvider.getCallStatusText(),
                    style: textStyle ?? TextStyle(
                      color: textColor ?? Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 로딩 인디케이터
          if (sipProvider.isLoading)
            Padding(
              padding: const EdgeInsets.only(left: AppConstants.spacingSm),
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.blue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Icon
  //--------------------------------------------------------------------------
  
  Widget _buildStatusIcon(SipProvider sipProvider) {
    final icon = _getStatusIcon(sipProvider);
    final color = _getStatusColor(sipProvider);
    
    return Icon(icon, color: color, size: iconSize);
  }

  //--------------------------------------------------------------------------
  // Status Icon
  //--------------------------------------------------------------------------
  
  IconData _getStatusIcon(SipProvider sipProvider) {
    switch (sipProvider.sipState) {
      case SipClientState.idle:
        return Icons.radio_button_unchecked_outlined;
      case SipClientState.connecting:
        return Icons.timer_outlined;
      case SipClientState.connected:
        return Icons.link_outlined;
      case SipClientState.registered:
        return Icons.check_circle_outline;
      case SipClientState.unregistered:
        return Icons.radio_button_unchecked_outlined;
      case SipClientState.disconnected:
        return Icons.link_off_outlined;
      case SipClientState.error:
        return Icons.error_outline;
    }
  }

  //--------------------------------------------------------------------------
  // Status Color
  //--------------------------------------------------------------------------
  
  Color _getStatusColor(SipProvider sipProvider) {
    switch (sipProvider.sipState) {
      case SipClientState.idle:
      case SipClientState.unregistered:
        return Colors.grey;
      case SipClientState.connecting:
        return Colors.blue;
      case SipClientState.connected:
      case SipClientState.registered:
        return Colors.green;
      case SipClientState.disconnected:
        return Colors.orange;
      case SipClientState.error:
        return Colors.red;
    }
  }
}

/// SIP 상태 칩 위젯
/// 
/// 작은 크기의 SIP 상태를 표시하는 칩 형태의 위젯입니다.
class SipStatusChip extends StatelessWidget {
  /// SIP Provider
  final SipProvider sipProvider;
  
  /// 크기
  final double size;
  
  /// 생성자
  const SipStatusChip({
    super.key,
    required this.sipProvider,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor(sipProvider).withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: _getStatusColor(sipProvider),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          _getStatusIcon(sipProvider),
          color: _getStatusColor(sipProvider),
          size: size * 0.5,
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Icon
  //--------------------------------------------------------------------------
  
  IconData _getStatusIcon(SipProvider sipProvider) {
    if (sipProvider.isInCall) {
      return Icons.call_outlined;
    }
    switch (sipProvider.sipState) {
      case SipClientState.idle:
      case SipClientState.unregistered:
        return Icons.radio_button_unchecked_outlined;
      case SipClientState.connecting:
        return Icons.timer_outlined;
      case SipClientState.connected:
        return Icons.link_outlined;
      case SipClientState.registered:
        return Icons.check_circle_outline;
      case SipClientState.disconnected:
        return Icons.link_off_outlined;
      case SipClientState.error:
        return Icons.error_outline;
    }
  }

  //--------------------------------------------------------------------------
  // Status Color
  //--------------------------------------------------------------------------
  
  Color _getStatusColor(SipProvider sipProvider) {
    if (sipProvider.isInCall) {
      return Colors.green;
    }
    switch (sipProvider.sipState) {
      case SipClientState.idle:
      case SipClientState.unregistered:
        return Colors.grey;
      case SipClientState.connecting:
        return Colors.blue;
      case SipClientState.connected:
      case SipClientState.registered:
        return Colors.green;
      case SipClientState.disconnected:
        return Colors.orange;
      case SipClientState.error:
        return Colors.red;
    }
  }
}

/// 네트워크 상태 바 위젯
/// 
/// 네트워크 연결 상태, ICE 상태 등을 표시합니다.
class NetworkStatusBar extends StatelessWidget {
  /// ICE 연결 상태
  final String iceConnectionState;
  
  /// Network status
  final String networkStatus;
  
  /// 생성자
  const NetworkStatusBar({
    super.key,
    required this.iceConnectionState,
    required this.networkStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ICE 연결 상태
          _buildStatusItem(
            icon: Icons.network_check_outlined,
            label: 'ICE: $iceConnectionState',
            color: _getIceColor(iceConnectionState),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          
          // 네트워크 상태
          _buildStatusItem(
            icon: Icons.signal_cellular_alt_outlined,
            label: networkStatus,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Status Item
  //--------------------------------------------------------------------------
  
  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: AppConstants.spacingXs),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // ICE Color
  //--------------------------------------------------------------------------
  
  Color _getIceColor(String state) {
    switch (state.toLowerCase()) {
      case 'new':
      case 'checking':
        return Colors.blue;
      case 'connected':
      case 'completed':
        return Colors.green;
      case 'failed':
      case 'disconnected':
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
