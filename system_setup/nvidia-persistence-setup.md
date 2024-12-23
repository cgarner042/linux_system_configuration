# Setting up nvidia-persistenced

## Standard Setup
1. Check the status of nvidia-persistenced
```bash
sudo systemctl status nvidia-persistenced
```

2. Enable nvidia-persistenced
```bash
sudo systemctl enable nvidia-persistenced
```

3. Reboot for execution
```bash
sudo reboot
```

## Troubleshooting Steps
If issues occur in step 2, follow these additional steps:

4. Open nvidia-persistenced.service
```bash
sudo gedit /lib/systemd/system/nvidia-persistenced.service
```

5. Modify and add content to the file:

   1) Modify the line in `[Service]` section:
   ```ini
   [Service]
   # Change from:
   ExecStart=/usr/bin/nvidia-persistenced --user nvidia-persistenced --no-persistence-mode --verbose
   # To:
   ExecStart=/usr/bin/nvidia-persistenced --user nvidia-persistenced --persistence-mode --verbose
   ```

   2) Add these lines to the file:
   ```ini
   [Install]
   WantedBy=multi-user.target
   RequiredBy=nvidia.service
   ```

## Note
For a temporary solution to set nvidia-persistenced, use:
```bash
sudo nvidia-smi -pm 1
```
