# Run multiple self hosted runner on same machine

# Install:
```bash
./config.sh --url https://github.com/UseR/repoName --token xxxxxxxxxxxxxxx
```
```bash
# to update when THIS repo files update
./service.sh install
```

# Control:
```bash
systemctl enable github-actions@UseR@repoName.service
systemctl start github-actions@UseR@repoName.service
```

# Uninstall:
```bash
./service.sh uninstall
```
