#!/bin/bash

# Reset ClientNote to use Ollama as the default AI backend
echo "Resetting ClientNote to use Ollama..."

# Use defaults command to set the preference
defaults write ai.tucuxi.ClientNote selectedAIBackend -string "ollamaKit"

echo "Done! ClientNote will now use Ollama as the AI backend."
echo "Please restart the app for changes to take effect." 