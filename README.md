# Run multiple [self-hosted] github actions runner on one machine

Powered by overlayfs, **linux only**.

# Download runner binary:
```bash
bash lib/check-update.sh
```

# Install:
```bash
./service.sh install

# for each project
./config.sh --url https://github.com/UseR/repoName --token xxxxxxxxxxxxxxx
```

# Control:
```bash
systemctl enable github-actions@UseR@repoName.service
systemctl start github-actions@UseR@repoName.service
```

### Control all service:
```bash
./service.sh start|stop|restart
```

### Uninstall:
```bash
./service.sh uninstall
```

### And more...
