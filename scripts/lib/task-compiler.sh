#!/bin/bash

# shellcheck shell=bash

vtc_trim() {
    printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

vtc_append_line() {
    local var_name="$1"
    local line="$2"
    local current_value

    line="$(vtc_trim "$line")"
    [[ -n "$line" ]] || return 0

    current_value="$(eval "printf '%s' \"\${$var_name:-}\"")"
    if [[ -n "$current_value" ]]; then
        printf -v "$var_name" '%s\n%s' "$current_value" "$line"
    else
        printf -v "$var_name" '%s' "$line"
    fi
}

vtc_first_nonempty_line() {
    awk 'NF{print; exit}' <<< "$1"
}

vtc_dedupe_lines() {
    awk '
        {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            if ($0 == "") {
                next
            }
            key = tolower($0)
            if (!(key in seen)) {
                seen[key] = 1
                print $0
            }
        }
    ' <<< "$1"
}

vtc_to_bullets() {
    local source="$1"
    local result=""
    local line trimmed

    while IFS= read -r line; do
        trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[-*]?[[:space:]]*//')"
        trimmed="$(vtc_trim "$trimmed")"
        [[ -n "$trimmed" ]] || continue
        if [[ -n "$result" ]]; then
            result+=$'\n'
        fi
        result+="- $trimmed"
    done <<< "$(vtc_dedupe_lines "$source")"

    printf '%s' "$result"
}

vtc_detect_language() {
    local text lower pt_count en_count
    text="$1"
    lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

    pt_count="$(grep -Eoi '(dado que|gostaria|para testar|não|nao|manter compatibilidade|sem quebrar|ficheiro|aceder|traduz|validação|restrições|objetivo|tarefa)' <<< "$lower" | wc -l | tr -d ' ')"
    en_count="$(grep -Eoi '(given|would like|for testing|do not|must not|keep compatibility|without breaking|file|access|translate|validation|constraints|goal|task)' <<< "$lower" | wc -l | tr -d ' ')"

    if (( pt_count > en_count )); then
        printf 'pt'
    elif (( en_count > pt_count )); then
        printf 'en'
    else
        printf 'mixed'
    fi
}

vtc_resolve_output_language() {
    local requested="$1"
    local input_language="$2"

    case "$requested" in
        auto)
            if [[ "$input_language" == "pt" ]]; then
                printf 'pt'
            else
                printf 'en'
            fi
            ;;
        pt)
            printf 'pt'
            ;;
        *)
            printf 'en'
            ;;
    esac
}

vtc_extract_references() {
    local text="$1"
    {
        grep -Eo '@[[:alnum:]_./-]+' <<< "$text" || true
        grep -Eo 'https?://[^[:space:])"]+' <<< "$text" || true
        grep -Eo '([[:alnum:]_.-]+/)+[[:alnum:]_.-]+\.[[:alnum:]_-]+' <<< "$text" || true
    } | sed -E 's/[.,;:!?]+$//' | awk 'NF' | awk '!seen[$0]++'
}

vtc_detect_task_type() {
    local text lower
    text="$1"
    lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lower" =~ (translate|traduz|tradu[cç][aã]o|i18n|localiza|hardcoded|lang/|pt\.json|locale) ]]; then
        printf 'i18n'
        return
    fi

    if [[ "$lower" =~ (ui|ux|menu|layout|tailwind|css|frontend|browser|playwright|clicar|click|navegador) ]]; then
        printf 'ui'
        return
    fi

    if [[ "$lower" =~ (refactor|refatora|reestrutur|cleanup|clean[- ]?up|simplif) ]]; then
        printf 'refactor'
        return
    fi

    if [[ "$lower" =~ (bug|erro|falha|fix|corrig) ]]; then
        printf 'bugfix'
        return
    fi

    if [[ "$lower" =~ (test|teste|testing|validation|valida[cç][aã]o|pest|phpunit|playwright|cypress|selenium) ]]; then
        printf 'tests'
        return
    fi

    if [[ "$lower" =~ (doc|documenta|readme|guia|guide) ]]; then
        printf 'documentation'
        return
    fi

    if [[ "$lower" =~ (cli|command|script|tooling|dev tooling|terminal) ]]; then
        printf 'tooling'
        return
    fi

    printf 'general'
}

vtc_is_constraint_sentence() {
    local lower="$1"
    [[ "$lower" =~ ((não|nao)[[:space:]]+(alterar|modificar|mudar|quebrar|mexer|tocar|remover)|do[[:space:]]+not[[:space:]]+(change|modify|break|touch|remove)|must[[:space:]]+not|don.t[[:space:]]+(change|modify|break)|sem[[:space:]]+quebrar|without[[:space:]]+breaking|manter[[:space:]]+compatibilidade|keep[[:space:]]+compatibility) ]]
}

vtc_is_validation_sentence() {
    local lower="$1"
    [[ "$lower" =~ (para testar|validar|valida[cç][aã]o|playwright|browser|navegador|executar testes|run tests|testar|testing|qa|cypress|selenium) ]]
}

vtc_is_context_sentence() {
    local lower="$1"
    [[ "$lower" =~ (^dado[[:space:]]+que|^given|atualmente|currently|já existe|ja existe|existing|hardcoded|não traduz|nao traduz|because|devido) ]]
}

vtc_is_success_sentence() {
    local lower="$1"
    [[ "$lower" =~ (success|sucesso|crit[eé]rio|criteria|done when|definition of done|conclu[ií]do|sem erros|passes|passar) ]]
}

vtc_parse_explicit_sections() {
    local text="$1"
    local current_section=""
    local line stripped lower content
    local nocase_was_set=0

    if shopt -q nocasematch; then
        nocase_was_set=1
    fi
    shopt -s nocasematch

    VTC_RAW_GOAL=""
    VTC_RAW_CONTEXT=""
    VTC_RAW_CONSTRAINTS=""
    VTC_RAW_SUCCESS=""
    VTC_RAW_VALIDATION=""
    VTC_RAW_PRIVATE=""

    while IFS= read -r line; do
        stripped="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[-*][[:space:]]*//; s/[[:space:]]+$//')"
        stripped="$(vtc_trim "$stripped")"
        [[ -n "$stripped" ]] || continue

        lower="$(printf '%s' "$stripped" | tr '[:upper:]' '[:lower:]')"

        content=""
        if [[ "$stripped" =~ ^(task|goal|objetivo|tarefa|feature|scenario|cen[aá]rio)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="goal"
            content="${BASH_REMATCH[2]}"
        elif [[ "$stripped" =~ ^(context|contexto|given|dado[[:space:]]+que|background)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="context"
            content="${BASH_REMATCH[2]}"
        elif [[ "$stripped" =~ ^(constraints?|restri[cç][aã]o|restri[cç][oõ]es|non-goals?|n[ãa]o[[:space:]]+alterar|n[ãa]o[[:space:]]+modificar|do[[:space:]]+not|manter[[:space:]]+compatibilidade|sem[[:space:]]+quebrar)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="constraints"
            content="${BASH_REMATCH[2]}"
        elif [[ "$stripped" =~ ^(success[[:space:]]+criteria|success|acceptance[[:space:]]+criteria|criteria|crit[eé]rios?[[:space:]]+de[[:space:]]+sucesso|sucesso|done[[:space:]]+when|definition[[:space:]]+of[[:space:]]+done)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="success"
            content="${BASH_REMATCH[2]}"
        elif [[ "$stripped" =~ ^(validation|validate|testing|tests?|valida[cç][aã]o|para[[:space:]]+testar|qa)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="validation"
            content="${BASH_REMATCH[2]}"
        elif [[ "$stripped" =~ ^(private[[:space:]]+deliverables?|deliverables?|entreg[aá]veis[[:space:]]+privados?|entreg[aá]veis[[:space:]]+internos|artefatos[[:space:]]+internos|private[[:space:]]+artifacts?)[[:space:]]*[:\-]?[[:space:]]*(.*)$ ]]; then
            current_section="private"
            content="${BASH_REMATCH[2]}"
        fi

        if [[ -n "$current_section" && "$content" != "" ]]; then
            case "$current_section" in
                goal) vtc_append_line VTC_RAW_GOAL "$content" ;;
                context) vtc_append_line VTC_RAW_CONTEXT "$content" ;;
                constraints) vtc_append_line VTC_RAW_CONSTRAINTS "$content" ;;
                success) vtc_append_line VTC_RAW_SUCCESS "$content" ;;
                validation) vtc_append_line VTC_RAW_VALIDATION "$content" ;;
                private) vtc_append_line VTC_RAW_PRIVATE "$content" ;;
            esac
            continue
        fi

        if [[ -n "$current_section" && "$content" == "" && "$lower" =~ ^(task|goal|objetivo|tarefa|feature|scenario|cen[aá]rio|context|contexto|given|dado[[:space:]]+que|background|constraints?|restri[cç][aã]o|restri[cç][oõ]es|non-goals?|success[[:space:]]+criteria|acceptance[[:space:]]+criteria|criteria|sucesso|validation|validate|testing|tests?|valida[cç][aã]o|para[[:space:]]+testar|private[[:space:]]+deliverables?|deliverables?)$ ]]; then
            continue
        fi

        if [[ "$lower" =~ ^(given|dado[[:space:]]+que)[[:space:]]+ ]]; then
            vtc_append_line VTC_RAW_CONTEXT "$stripped"
            continue
        fi

        if [[ "$lower" =~ ^(when|quando)[[:space:]]+ ]]; then
            vtc_append_line VTC_RAW_CONTEXT "$stripped"
            continue
        fi

        if [[ "$lower" =~ ^(then|ent[aã]o)[[:space:]]+ ]]; then
            vtc_append_line VTC_RAW_SUCCESS "$stripped"
            continue
        fi

        case "$current_section" in
            goal) vtc_append_line VTC_RAW_GOAL "$stripped" ;;
            context) vtc_append_line VTC_RAW_CONTEXT "$stripped" ;;
            constraints) vtc_append_line VTC_RAW_CONSTRAINTS "$stripped" ;;
            success) vtc_append_line VTC_RAW_SUCCESS "$stripped" ;;
            validation) vtc_append_line VTC_RAW_VALIDATION "$stripped" ;;
            private) vtc_append_line VTC_RAW_PRIVATE "$stripped" ;;
        esac
    done <<< "$text"

    if [[ "$nocase_was_set" -eq 0 ]]; then
        shopt -u nocasematch
    fi
}

vtc_collect_heuristics() {
    local text="$1"
    local line chunk lower

    VTC_INF_GOAL=""
    VTC_INF_CONTEXT=""
    VTC_INF_CONSTRAINTS=""
    VTC_INF_SUCCESS=""
    VTC_INF_VALIDATION=""

    while IFS= read -r line; do
        line="$(vtc_trim "$line")"
        [[ -n "$line" ]] || continue

        while IFS= read -r chunk; do
            chunk="$(vtc_trim "$chunk")"
            [[ -n "$chunk" ]] || continue

            lower="$(printf '%s' "$chunk" | tr '[:upper:]' '[:lower:]')"

            if [[ -z "$VTC_INF_GOAL" ]]; then
                printf -v VTC_INF_GOAL '%s' "$chunk"
            fi

            if vtc_is_constraint_sentence "$lower"; then
                vtc_append_line VTC_INF_CONSTRAINTS "$chunk"
            fi

            if vtc_is_validation_sentence "$lower"; then
                vtc_append_line VTC_INF_VALIDATION "$chunk"
            fi

            if vtc_is_context_sentence "$lower" || [[ "$chunk" =~ (@[[:alnum:]_./-]+|https?://) ]]; then
                vtc_append_line VTC_INF_CONTEXT "$chunk"
            fi

            if vtc_is_success_sentence "$lower"; then
                vtc_append_line VTC_INF_SUCCESS "$chunk"
            fi
        done <<< "$(printf '%s' "$line" | sed -E 's/([.!?])[[:space:]]+([A-ZÁÉÍÓÚÂÊÔÃÕÇ])/\1\n\2/g; s/[;]+/\n/g')"
    done <<< "$text"
}

vtc_localized_line() {
    local key="$1"
    local lang="$2"
    local task_type="${3:-general}"

    if [[ "$lang" == "pt" ]]; then
        case "$key" in
            default_context) printf 'Solicitação compilada a partir do pedido em linguagem natural.' ;;
            default_constraint) printf 'Não modificar componentes não relacionados com o pedido.' ;;
            default_success) printf 'As alterações pedidas estão implementadas sem violar as restrições definidas.' ;;
            default_validation) printf 'Executar validação adequada antes de concluir a tarefa.' ;;
            inferred_goal) printf 'Objetivo inferido automaticamente a partir do texto livre.' ;;
            references_prefix) printf 'Artefactos referenciados:' ;;
            note_missing_goal) printf 'Goal foi inferido por ausência de secção explícita.' ;;
            note_missing_success) printf 'Success Criteria foi enriquecido heuristicamente por falta de critérios mensuráveis explícitos.' ;;
            note_missing_validation) printf 'Validation Instructions foi enriquecido com heurística por falta de instruções explícitas.' ;;
            ui_validation) printf 'Validar no browser (desktop e mobile) o fluxo afetado e confirmar o comportamento visual/interativo.' ;;
            i18n_constraint) printf 'Não deixar textos hardcoded voltados ao utilizador no escopo afetado; usar recursos de tradução apropriados.' ;;
            i18n_success) printf 'Todos os textos alterados estão em inglês no código e registados no ficheiro de traduções aplicável.' ;;
            tests_success) printf 'Todos os testes relacionados executam sem falhas e sem regressões evidentes.' ;;
            refactor_constraint) printf 'Manter compatibilidade comportamental sem alterar funcionalidades além do escopo pedido.' ;;
            bugfix_success) printf 'O cenário reportado deixa de falhar e um caso de regressão confirma a correção.' ;;
            none) printf 'none' ;;
            *) printf '%s' "$key" ;;
        esac
    else
        case "$key" in
            default_context) printf 'Compiled from the natural-language engineering request.' ;;
            default_constraint) printf 'Do not modify unrelated components outside the requested scope.' ;;
            default_success) printf 'Requested changes are implemented while respecting stated constraints.' ;;
            default_validation) printf 'Run appropriate validation before finalizing the task.' ;;
            inferred_goal) printf 'Goal inferred automatically from freeform request.' ;;
            references_prefix) printf 'Referenced artifacts:' ;;
            note_missing_goal) printf 'Goal was inferred because no explicit goal section was detected.' ;;
            note_missing_success) printf 'Success Criteria was heuristically enriched because no measurable criteria were explicitly provided.' ;;
            note_missing_validation) printf 'Validation Instructions was heuristically enriched because no explicit testing steps were provided.' ;;
            ui_validation) printf 'Validate the affected flow in browser (desktop and mobile) and confirm visual/interaction behavior.' ;;
            i18n_constraint) printf 'Do not leave user-facing hardcoded strings in affected scope; use appropriate translation resources.' ;;
            i18n_success) printf 'Updated user-facing strings are in English in code and mapped in the appropriate translation resource file.' ;;
            tests_success) printf 'Relevant tests run successfully with no obvious regressions.' ;;
            refactor_constraint) printf 'Preserve existing behavior and compatibility; avoid functional changes beyond requested scope.' ;;
            bugfix_success) printf 'Reported failing scenario no longer reproduces and a regression check confirms the fix.' ;;
            none) printf 'none' ;;
            *) printf '%s' "$key" ;;
        esac
    fi
}

vtc_apply_task_type_heuristics() {
    local lang="$1"
    local task_type="$2"

    case "$task_type" in
        ui)
            if [[ -z "$VTC_VALIDATION_LINES" ]]; then
                vtc_append_line VTC_VALIDATION_LINES "$(vtc_localized_line ui_validation "$lang")"
            fi
            ;;
        i18n)
            vtc_append_line VTC_CONSTRAINT_LINES "$(vtc_localized_line i18n_constraint "$lang")"
            vtc_append_line VTC_SUCCESS_LINES "$(vtc_localized_line i18n_success "$lang")"
            ;;
        bugfix)
            vtc_append_line VTC_SUCCESS_LINES "$(vtc_localized_line bugfix_success "$lang")"
            ;;
        refactor)
            vtc_append_line VTC_CONSTRAINT_LINES "$(vtc_localized_line refactor_constraint "$lang")"
            ;;
        tests)
            vtc_append_line VTC_SUCCESS_LINES "$(vtc_localized_line tests_success "$lang")"
            ;;
    esac
}

vtc_compile_text() {
    local raw_text="$1"
    local requested_output_language="$2"
    local enrich_mode="${3:-repo-aware}"
    local references_summary=""
    local references_text=""
    local diagnostics=""
    local goal_line=""
    local input_language resolved_output_language task_type

    VTC_DIAGNOSTICS=""
    VTC_REFERENCES=""

    input_language="$(vtc_detect_language "$raw_text")"
    resolved_output_language="$(vtc_resolve_output_language "$requested_output_language" "$input_language")"
    task_type="$(vtc_detect_task_type "$raw_text")"
    references_text="$(vtc_extract_references "$raw_text")"

    vtc_parse_explicit_sections "$raw_text"
    vtc_collect_heuristics "$raw_text"

    goal_line="$(vtc_first_nonempty_line "$VTC_RAW_GOAL")"
    if [[ -z "$goal_line" ]]; then
        if [[ "$VTC_RAW_CONTEXT" =~ [Gg]ostaria[[:space:]]+que[[:space:]](.+) ]]; then
            goal_line="$(vtc_trim "${BASH_REMATCH[1]}")"
        elif [[ "$VTC_RAW_CONTEXT" =~ [Ww]ould[[:space:]]+like[[:space:]](.+) ]]; then
            goal_line="$(vtc_trim "${BASH_REMATCH[1]}")"
        fi
        goal_line="$(printf '%s' "$goal_line" | sed -E 's/[[:space:]]+([Pp]ara[[:space:]]+testar|[Nn][ãa]o[[:space:]]+modificar|[Dd]o[[:space:]]+not|[Vv]alidar).*$//')"
        goal_line="$(vtc_trim "$goal_line")"
    fi
    if [[ -z "$goal_line" ]]; then
        goal_line="$(vtc_first_nonempty_line "$VTC_INF_GOAL")"
        if [[ -z "$goal_line" ]]; then
            goal_line="$(vtc_localized_line inferred_goal "$resolved_output_language" "$task_type")"
        fi
        vtc_append_line diagnostics "$(vtc_localized_line note_missing_goal "$resolved_output_language" "$task_type")"
    fi

    VTC_CONTEXT_LINES="$VTC_RAW_CONTEXT"
    if [[ -z "$VTC_CONTEXT_LINES" ]]; then
        VTC_CONTEXT_LINES="$VTC_INF_CONTEXT"
    fi
    if [[ -z "$VTC_CONTEXT_LINES" ]]; then
        vtc_append_line VTC_CONTEXT_LINES "$(vtc_localized_line default_context "$resolved_output_language" "$task_type")"
    fi

    VTC_CONSTRAINT_LINES="$VTC_RAW_CONSTRAINTS"
    if [[ -z "$VTC_CONSTRAINT_LINES" ]]; then
        VTC_CONSTRAINT_LINES="$VTC_INF_CONSTRAINTS"
    fi
    if [[ -z "$VTC_CONSTRAINT_LINES" ]]; then
        vtc_append_line VTC_CONSTRAINT_LINES "$(vtc_localized_line default_constraint "$resolved_output_language" "$task_type")"
    fi

    VTC_SUCCESS_LINES="$VTC_RAW_SUCCESS"
    if [[ -z "$VTC_SUCCESS_LINES" ]]; then
        VTC_SUCCESS_LINES="$VTC_INF_SUCCESS"
    fi
    if [[ -z "$VTC_SUCCESS_LINES" ]]; then
        vtc_append_line VTC_SUCCESS_LINES "$(vtc_localized_line default_success "$resolved_output_language" "$task_type")"
        vtc_append_line diagnostics "$(vtc_localized_line note_missing_success "$resolved_output_language" "$task_type")"
    fi

    VTC_VALIDATION_LINES="$VTC_RAW_VALIDATION"
    if [[ -z "$VTC_VALIDATION_LINES" ]]; then
        VTC_VALIDATION_LINES="$VTC_INF_VALIDATION"
    fi

    if [[ -z "$VTC_VALIDATION_LINES" && "$task_type" =~ ^(ui|tests)$ ]]; then
        vtc_append_line VTC_VALIDATION_LINES "$(vtc_localized_line default_validation "$resolved_output_language" "$task_type")"
        vtc_append_line diagnostics "$(vtc_localized_line note_missing_validation "$resolved_output_language" "$task_type")"
    fi

    if [[ "$enrich_mode" == "repo-aware" ]]; then
        vtc_apply_task_type_heuristics "$resolved_output_language" "$task_type"
    fi

    if [[ -n "$references_text" ]]; then
        references_summary="$(awk 'BEGIN{first=1} { if (!first) { printf ", " } printf "%s", $0; first=0 } END { printf "\n" }' <<< "$references_text")"
        references_summary="$(vtc_trim "$references_summary")"
        vtc_append_line VTC_CONTEXT_LINES "$(vtc_localized_line references_prefix "$resolved_output_language" "$task_type") $references_summary"
    fi

    VTC_GOAL="$goal_line"
    VTC_CONTEXT="$(vtc_to_bullets "$VTC_CONTEXT_LINES")"
    VTC_CONSTRAINTS="$(vtc_to_bullets "$VTC_CONSTRAINT_LINES")"
    VTC_SUCCESS="$(vtc_to_bullets "$VTC_SUCCESS_LINES")"
    VTC_VALIDATION="$(vtc_to_bullets "$VTC_VALIDATION_LINES")"
    VTC_PRIVATE="$(vtc_to_bullets "$VTC_RAW_PRIVATE")"
    VTC_REFERENCES="$(vtc_dedupe_lines "$references_text")"
    VTC_DIAGNOSTICS="$(vtc_to_bullets "$diagnostics")"

    [[ -n "$VTC_CONTEXT" ]] || VTC_CONTEXT="- $(vtc_localized_line default_context "$resolved_output_language" "$task_type")"
    [[ -n "$VTC_CONSTRAINTS" ]] || VTC_CONSTRAINTS="- $(vtc_localized_line default_constraint "$resolved_output_language" "$task_type")"
    [[ -n "$VTC_SUCCESS" ]] || VTC_SUCCESS="- $(vtc_localized_line default_success "$resolved_output_language" "$task_type")"
    [[ -n "$VTC_VALIDATION" ]] || VTC_VALIDATION="- $(vtc_localized_line default_validation "$resolved_output_language" "$task_type")"
    [[ -n "$VTC_PRIVATE" ]] || VTC_PRIVATE="- $(vtc_localized_line none "$resolved_output_language" "$task_type")"

    VTC_INPUT_LANGUAGE="$input_language"
    VTC_OUTPUT_LANGUAGE="$resolved_output_language"
    VTC_TASK_TYPE="$task_type"
}
