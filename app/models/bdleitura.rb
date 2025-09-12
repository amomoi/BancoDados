class Bdleitura < ApplicationRecord
    belongs_to :bdsensor

    before_save :check_status

    def check_status  
        # Carrega o sensor e o cliente associado de uma vez
        sensor = Bdsensor.find_by(id: bdsensor_id)
        # Se o sensor não existir, aborta o salvamento
        unless sensor
            errors.add(:base, "Sensor não encontrado.")
            throw(:abort)
        end

        cliente = Bdcliente.find_by(id: sensor.bdcliente_id)
        # Se o cliente não existir, aborta o salvamento
        unless cliente
            errors.add(:base, "Cliente não encontrado.")
            throw(:abort)
        end

        p "Cliente: #{cliente.id}"
        p "Cliente Ativo/Inativo: #{cliente.ativo_inativo}"
        p "Sensor ID: #{sensor.id}"
        p "Sensor Ativo/Inativo: #{sensor.ativo_inativo}"

        # Carrega as flags e limites uma única vez do objeto sensor carregado
        flag_notificacao = sensor.flag_notificacao.to_i
        flag_rearme = sensor.flag_rearme.to_i
        flag_mantec = sensor.flag_mantec.to_i
        limite_inferior = sensor.LI.to_f if sensor.LI.present?
        limite_superior = sensor.LS.to_f if sensor.LS.present?
        
        valor_f = valor.to_f # 'valor' é o atributo da Bdleitura que está sendo salva

        # Lógica de verificação de status do cliente e sensor
        if cliente.ativo_inativo != 1 || sensor.ativo_inativo != 1
            errors.add(:base, "Salvamento cancelado pois cliente ou sensor está inativo.")
            throw(:abort)
        end

        # Lógica de Manutenção (flag_mantec)
        if flag_mantec == 1
            sensor.update(flag_rearme: 0, flag_notificacao: 0)
            Rails.logger.info "Manutenção ativada para Sensor #{sensor.id}, flags zerados: flag_rearme=0, flag_notificacao=0"
            # Importante: Como a manutenção está ativa, não faremos mais nada para esta leitura
            return # Sai do método check_status
        end

        # Lógica de verificação de limites (se não estiver em manutenção)
        violou_inferior = limite_inferior.present? && (valor_f <= limite_inferior)
        violou_superior = limite_superior.present? && (valor_f >= limite_superior)
        fora_do_limite = violou_inferior || violou_superior

        Rails.logger.info "Sensor #{sensor.id} - LI=#{limite_inferior.inspect} LS=#{limite_superior.inspect} " \
                       "Valor=#{valor_f} => violou_inf=#{violou_inferior} violou_sup=#{violou_superior}"

        if fora_do_limite
            # fora do(s) limite(s)
            if flag_notificacao == 0 # Só atualiza para 1 se ainda não estiver 1
                sensor.update(flag_notificacao: 1)
                Rails.logger.info "Sensor #{sensor.id} - Notificação ativada (fora do limite): flag_notificacao=1"
            end
        else
            # dentro do(s) limite(s) definidos (ou nenhum limite definido)
            if flag_notificacao == 1 || flag_rearme == 1 # Só atualiza se precisar zerar
                sensor.update(flag_notificacao: 0, flag_rearme: 0)
                Rails.logger.info "Sensor #{sensor.id} - Valor dentro dos limites; flags zerados: flag_notificacao=0, flag_rearme=0"
            end
        end


          

            # if cliente_ativo_inativo == 1 && sensor_ativo_inativo == 1
            #       sms_ativo = Bdusuario.where("Bdcliente_id = ?", cliente[0]).select(:SMS).select(:nome).select(:ativo_inativo).select(:celular)

            #       sms_ativo.each do |s|
            #             if s[:SMS] == "1"

            #                   #AQUISICAO DOS PARAMETROS PARA LOGICA

            #                   p "LI"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:LI).pluck(:LI)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         limite_inferior = ""
            #                         p limite_inferior
            #                   else 
            #                         limite_inferior = Bdsensor.where("id = ?", bdsensor_id).select(:LI).pluck(:LI).first.to_f
            #                         p limite_inferior
            #                   end

            #                   p "LS"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:LS).pluck(:LS)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         limite_superior = ""
            #                         p limite_superior               
            #                   else 
            #                         limite_superior = Bdsensor.where("id = ?", bdsensor_id).select(:LS).pluck(:LS).first.to_f
            #                         p limite_superior
            #                   end

            #                   p "Valor anterior"
            #                   results = Bdleitura.where("bdsensor_id = ?", bdsensor_id).select(:valor)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p ""
            #                         p "Valor"
            #                         p valor
            #                   else 
            #                         valor_anterior = valor_anterior = Bdleitura.where("bdsensor_id = ?", bdsensor_id).select(:valor).last
            #                         p valor_anterior.valor
            #                         p "Valor"
            #                         p valor
            #                   end  


            #                   p "Flag notificacao"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_notificacao).pluck(:flag_notificacao)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_notificacao = ""
            #                   else 
            #                         flag_notificacao = Bdsensor.where("id = ?", bdsensor_id).select(:flag_notificacao).pluck(:flag_notificacao).first.to_i
            #                         p flag_notificacao
            #                   end

            #                   p "Flag rearme"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_rearme).pluck(:flag_rearme)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_rearme = ""                  
            #                   else 
            #                         flag_rearme = Bdsensor.where("id = ?", bdsensor_id).select(:flag_rearme).pluck(:flag_rearme).first.to_i
            #                         p flag_rearme
            #                   end

            #                   p "Flag mantec"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_mantec).pluck(:flag_mantec)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_mantec = ""
            #                   else 
            #                         flag_mantec = Bdsensor.where("id = ?", bdsensor_id).select(:flag_mantec).pluck(:flag_mantec).first.to_i
            #                         p flag_mantec
            #                   end

            #                   if limite_inferior != "" || limite_superior != "" 
            #                         if flag_mantec == 0 || flag_mantec == ""
            #                               if !limite_inferior != "" || !limite_superior != ""
            #                                     if valor <= limite_inferior || valor >= limite_superior #checa se atingiu o valor limite (superior ou inferior)
            #                                           p "Usuario ativo ou inativo"
            #                                           p s[:ativo_inativo]
            #                                           if s[:ativo_inativo] == 1
            #                                                 nome_da_empresa = Bdcliente.where("id = ?", cliente[0]).select(:nome_empresa).pluck(:nome_empresa)
            #                                                 p nome_da_empresa[0]
            #                                                 p bdsensor.nome_sensor
            #                                                 p "#{nome_da_empresa[0]} - #{s.nome}: SMS do Sensor #{bdsensor.nome_sensor} foi ativado #{Time.now.strftime("%I:%M%p - %d/%m/%Y")} pois atingiu o limite! Favor verificar!"
            #                                                 p "Enviou SMS por Leituras Controler"
            #                                                 BdleiturasController.enviarSMS(s[:celular], cliente[0], nome_da_empresa[0], s[:nome], bdsensor.nome_sensor)
            #                                           else
            #                                                 p "Nao enviou SMS pois usuario esta inativo"
            #                                           end 
            #                                     end
            #                               end
            #                         else #flag_mantec = 1
            #                               flag_notificacao = 0
            #                               flag_rearme = 0
            #                               p "Ativou Manutenção"
            #                         end
            #                   else
            #                         p "Nao tem LI ou LS cadastrado"
            #                   end
            #             else
            #                   p   "SMS desativado"
            #             end
            #       end
            # else

                  # #CANCELA SALVAMENTO POIS CLIENTE OU SENSOR ESTA INATIVO
                  # errors.add(:base, "Salvamento cancelado pois cliente ou sensor esta inativo")
                  # throw(:abort)
            #end
            
      end

end
