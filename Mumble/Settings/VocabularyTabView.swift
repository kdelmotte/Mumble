// VocabularyTabView.swift
// Mumble
//
// The "Vocabulary" tab in the Settings sidebar. Lets the user add spoken->corrected
// word pairs to fix recurring Whisper misspellings of proper nouns and brand names.

import SwiftUI

struct VocabularyTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mascot header
                Image("MumbleIconVocabulary")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .mascotGlow(color: .purple)

                VStack(spacing: 6) {
                    Text("Vocabulary")
                        .font(.mumbleDisplay(size: 22))

                    Text("Add words that are frequently misspelled by speech-to-text, like proper nouns and brand names.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Form {
                    Section {
                        // Column headers.
                        HStack {
                            Text("Spoken")
                                .font(.mumbleHeadline(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Corrected")
                                .font(.mumbleHeadline(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // Spacer for the delete button column.
                            Color.clear.frame(width: 28)
                        }
                        .padding(.horizontal, 4)

                        ForEach($viewModel.vocabularyConfig.entries) { $entry in
                            HStack {
                                TextField("", text: $entry.spoken, prompt: Text("e.g. cloud"))
                                    .textFieldStyle(.roundedBorder)
                                TextField("", text: $entry.corrected, prompt: Text("e.g. Claude"))
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    viewModel.removeVocabularyEntry(id: entry.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .labelsHidden()
                        }

                        Button {
                            viewModel.addVocabularyEntry()
                        } label: {
                            Label("Add Word Pair", systemImage: "plus.circle")
                                .foregroundStyle(Color(red: 0.91, green: 0.45, blue: 0.36))
                        }
                    } header: {
                        Text("Word Pairs")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How it works")
                                .font(.callout.weight(.medium))

                            Text("**Smart Formatting ON** — corrections are included in the LLM prompt with an instruction to apply them contextually. For example, \"cloud\" will only be replaced with \"Claude\" when it makes sense in context.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("**Smart Formatting OFF** — a simple find-and-replace is applied after tone formatting. Every occurrence of the spoken word is replaced, regardless of context.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
        .onChange(of: viewModel.vocabularyConfig) { _, _ in
            viewModel.saveVocabularyConfig()
        }
    }
}
