[Unit]
Description=KDE Configuration Module Initialization (Phase 1)
Requires=kcminit.service
After=kcminit.service kded.service

[Service]
Type=oneshot
ExecStart=@QtBinariesDir@/qdbus org.kde.kcminit /kcminit org.kde.KCMInit.runPhase1
