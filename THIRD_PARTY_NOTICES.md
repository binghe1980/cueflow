# Third-Party Notices / 第三方许可声明

CueFlow (随读) is open-source software released under the MIT License. It is a
derivative work of **NotchPrompt** and bundles / depends on several third-party
components. This file lists each upstream project and its license, as required
by those licenses (the Apache-2.0 components in particular require that their
NOTICE and attribution be preserved).

CueFlow（随读）以 MIT 协议开源，基于 **NotchPrompt** 二次开发，并内置/依赖以下
第三方组件。下表列出每个上游项目及其许可证。其中 Apache-2.0 组件要求保留署名与
NOTICE，特此声明。

---

## 1. NotchPrompt (base project / 基线项目)

- Source: https://github.com/saif0200/notchprompt
- Copyright (c) 2026 Saif
- License: **MIT**

CueFlow started as a fork of NotchPrompt and reuses portions of its source code.
The original MIT copyright notice is preserved in `LICENSE`.

## 2. WhisperKit

- Source: https://github.com/argmaxinc/WhisperKit
- Copyright (c) 2024 Argmax, Inc.
- License: **MIT**
- Usage: on-device speech recognition (Swift package dependency).

## 3. swift-transformers

- Source: https://github.com/huggingface/swift-transformers
- Copyright (c) Hugging Face, Inc.
- License: **Apache License 2.0**
- Usage: tokenizer support pulled in transitively by WhisperKit.

## 4. swift-argument-parser

- Source: https://github.com/apple/swift-argument-parser
- Copyright (c) Apple Inc. and the Swift project authors
- License: **Apache License 2.0**
- Usage: transitive dependency.

## 5. Whisper `base` speech model + tokenizer (bundled / 内置离线模型)

The release `.dmg` bundles a Core ML conversion of OpenAI's Whisper `base`
model together with its tokenizer files, so speech-follow works fully offline.

- Core ML model: https://huggingface.co/argmaxinc/whisperkit-coreml
  (Argmax conversion) — License: **MIT**
- Original model + tokenizer: https://github.com/openai/whisper
  (OpenAI) — License: **MIT**

The model is **not** stored in this Git repository (it is fetched at build time
via `scripts/fetch_whisper_model.sh`). It is only redistributed inside the
prebuilt `.dmg`.

---

## License texts / 许可证全文

### MIT License (applies to NotchPrompt, WhisperKit, Whisper model)

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Apache License 2.0 (applies to swift-transformers, swift-argument-parser)

These components are licensed under the Apache License, Version 2.0. You may
obtain a copy of the License at:

> http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
