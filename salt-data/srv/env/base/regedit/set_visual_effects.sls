# Disable visual effects for best performance to ensure smooth edges for fonts and scroll list boxes are disabled. Important for RF ImageHorizonLibrary!
set_visual_effects_for_best_performance:
  reg.present:
    - name: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects
    - vname: VisualFXSetting
    - vdata: 2
    - vtype: REG_DWORD