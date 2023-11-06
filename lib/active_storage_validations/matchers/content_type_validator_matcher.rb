# frozen_string_literal: true

# Big thank you to the paperclip validation matchers:
# https://github.com/thoughtbot/paperclip/blob/v6.1.0/lib/paperclip/matchers/validate_attachment_content_type_matcher.rb
module ActiveStorageValidations
  module Matchers
    def validate_content_type_of(name)
      ContentTypeValidatorMatcher.new(name)
    end

    class ContentTypeValidatorMatcher
      def initialize(attribute_name)
        @attribute_name = attribute_name
        @allowed_types = @rejected_types = []
        @custom_message = nil
      end

      def description
        "validate the content types allowed on attachment #{@attribute_name}"
      end

      def allowing(*types)
        @allowed_types = types.flatten
        self
      end

      def rejecting(*types)
        @rejected_types = types.flatten
        self
      end

      def with_message(message)
        @custom_message = message
        self
      end

      def matches?(subject)
        @subject = subject.is_a?(Class) ? subject.new : subject
        responds_to_methods && all_allowed_types_allowed? && all_rejected_types_rejected? && validate_custom_message?
      end

      def failure_message
        message = ["Expected #{@attribute_name}"]

        if @allowed_types_not_allowed.present?
          message << "Accept content types: #{@allowed_types.join(", ")}"
          message << "#{@allowed_types_not_allowed.join(", ")} were rejected"
        end

        if @rejected_types_not_rejected.present?
          message << "Reject content types: #{@rejected_types.join(", ")}"
          message << "#{@rejected_types_not_rejected.join(", ")} were accepted"
        end

        message.join("\n")
      end

      protected

      def responds_to_methods
        @subject.respond_to?(@attribute_name) &&
          @subject.public_send(@attribute_name).respond_to?(:attach) &&
          @subject.public_send(@attribute_name).respond_to?(:detach)
      end

      def all_allowed_types_allowed?
        @allowed_types_not_allowed ||= @allowed_types.reject { |type| type_allowed?(type) }
        @allowed_types_not_allowed.empty?
      end

      def all_rejected_types_rejected?
        @rejected_types_not_rejected ||= @rejected_types.select { |type| type_allowed?(type) }
        @rejected_types_not_rejected.empty?
      end

      def type_allowed?(type)
        @subject.public_send(@attribute_name).attach(attachment_for(type))
        @subject.validate
        @subject.errors.details[@attribute_name].none? do |error|
          error[:error].to_s.include?(error_message)
        end
      end

      def validate_custom_message?
        return true unless @custom_message

        @subject.public_send(@attribute_name).attach(attachment_for('fake/fake'))
        @subject.validate
        @subject.errors.details[@attribute_name].select{|error| error[:content_type]}.all? do |error|
          error[:error].to_s.include?(error_message)
        end
      end

      def error_message
        @custom_message || :content_type_invalid.to_s
      end

      def attachment_for(type)
        suffix = type.to_s.split('/').last
        { io: Tempfile.new('.'), filename: "test.#{suffix}", content_type: type }
      end
    end
  end
end
