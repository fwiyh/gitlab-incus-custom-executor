# GitLab incus custorm executor
## インストール概要
1. incusのリモート設定
2. /etc/gitlab-runner/config.tomlの修正
3. /opt/incus-driverに各種shellファイルを設置
4. GitLab管理者でCI/CD用のrunnerを登録
5. 各プロジェクトでCI/CD向けの変数を設定

## 事前にやること
- incusクライアントをインストール
- リモートの指定
```sh
incus remote add （任意に設定したリモート名） https://（incusマシンのIPアドレス）:（incus向けWebAPIのポート番号）
incus remote switch （任意に設定したリモート名）
# 修正は以下コマンドを実行
# incus remote set-url （任意に設定したリモート名） https://（incusマシンのIPアドレス）:（incus向けWebAPIのポート番号）
```

## 使い方
1. GitLabの各プロジェクトを開いて、`設定→CI/CD`を開く
2. `変数`の項目を展開して、プロジェクト変数のリストのヘッダーにある「変数を追加」を選択
3. 以下の変数を作成する
   1. `CI_JOB_IMAGE`: `images:debian/trixie/cloud`のような`リモートの名称:イメージ名`を指定
   2. `INCUS_LAUNCH_FLAGS`: 本当はブランクを設定したいが何かを設定しなければならないのであれば`--profile=default`にしておく
      - これら設定はincusのlaunchコマンドで利用する設定

---

## 以下、作成したExecutor固有の仕様

### 作成したincus-driver固有の変数
- これら変数はGitLab runner実行時に自動的に作成される変数のため参照のみ行っている
  - CUSTOM_ENV_CI_RUNNER_ID
    - 自動的に`CI_RUNNER_ID`が設定される
  - CUSTOM_ENV_CI_PROJECT_ID
    - 自動的に`CI_PROJECT_ID`が設定される
  - CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID
    - 自動的に`CI_CONCURRENT_PROJECT_ID`が設定される
  - CUSTOM_ENV_CI_JOB_ID
    - 自動的に`CI_JOB_ID`が設定される
  - CUSTOM_ENV_CI_JOB_IMAGE
    - incusコンテナを作成する際に利用するLinux Containerのimage名
    - linuxcontainer.orgからincus経由で利用可能なものからincus内で作成したものも含めて設定可能
    - 各プロジェクトのCI/CDの設定で作成した変数の`CI_JOB_IMAGE`をそのまま受け取っている

### 予約済み変数
- 以下の変数はincus-driverが内部的に利用しているため外部から変更してはいけない
  - CONTAINER_ID
    - `base.sh`で作成コンテナ名を生成したもの
  - SYSTEM_FAILURE_EXIT_CODE・BUILD_FAILURE_EXIT_CODE
    - shell内部で自動的に出力されるものなので上書きする必要がない

---

# 以下、gitlab-runnerに関する仕様

## gitlab-runner共通のルール
### runnerで利用できる変数のルール
- `.gitlab-ci.yml`で設定されている項目は「定義済みのCI/CD変数」を利用できる
- `.gitlab-ci.yml`の`variables:`領域で任意の変数を設定でき、それ以外のyamlファイルで利用できる
- グローバル変数を上書きしたい場合はジョブの中で意図的に設定を行う
  - `variables: {}`
- Executorで定義された環境変数をExecutorで利用する場合は`CUSTOM_ENV_`を変数の頭につける
  - 例）CI_JOB_IMAGE→CUSTOM_ENV_CI_JOB_IMAGE

### 変数
- [Predefined CI/CD variables reference](https://docs.gitlab.com/ci/variables/predefined_variables/#predefined-cicd-variables-reference)ここに設定されているものをCI実行時にyaml経由で渡す


## 未実装項目
### 将来的に検討すべき内容
- ContainerかVMかを判別する変数
  - 現状、containerでのCIを想定しているため

## 参考情報・過去に検討した話
- 何らかの理由で改修をするときに参考にすべきドキュメントなど

### GitLab Runner定義済み変数
- 出典:[Custom Executor](https://docs.gitlab.com/runner/executors/custom/)
- [Predefined CI/CD variables reference](https://docs.gitlab.com/ci/variables/predefined_variables/)
  - 基本的にここの定義を利用するだけでoverrideは考えない前提で運用
- [Available settings for services](https://docs.gitlab.com/ci/services/#available-settings-for-services)
  - json形式で`CUSTOM_ENV_CI_JOB_SERVICES`として出力されるらしいので確認するならこの変数のjson

### incus driverをashで作成しようとしたときの調査と検討事項
- よくある開発言語との差異 
  - `=`のような記号の間にスペースを入れてはいけない
    - 何等かの実行ファイルを動かそうとするためスペースを入れると実行ファイルの引数として認識される
  - 変数宣言は文字列、利用する場合は`$`を付与して変数を出力する
- 比較演算のイコールは`==`ではなく`=`で変数との間にスペースを入れる必要がある
- 外部ファイルの読み込みは`source`が使えないので`.`を利用
  - `. ./base.sh`のように絶対パスか相対パスを含め`.`や`/`の記述が必要
- `TRAP`構文をどう作るか検討が必要なため当分はbashで動かす前提にしておく

```sh
#!/bin/sh
testVal="aaa"
echo $testVal

for i in $(seq 1 "$timeout"); do
    if [ "$i" = "3" ]; then
        break
    fi

    if [ "$i" = "$timeout" ]; then
        echo 'Waited for 10 seconds to start container, exiting..'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    echo "current count: $i"

    sleep 1s
done

```
