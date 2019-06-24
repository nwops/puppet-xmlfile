# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:xmlfile_modification) do
  let(:testobject) { Puppet::Type.type(:xmlfile_modification) }

  describe 'file' do
    it 'is a fully-qualified path' do
      expect {
        testobject.new(
          name: 'foo',
          file: 'my/path',
        )
      }.to raise_error(Puppet::Error, %r{paths must be fully qualified})
    end
    it 'should be required'
  end

  describe 'changes' do
    it 'requires a fully-qualified xpath' do
      expect {
        testobject.new(
          name: 'test',
          file: '/my/path',
          changes: ['set blah/bloo/hah "test"'],
        )
      }.to raise_error(Puppet::Error, %r{invalid xpath})
    end
    it 'does not accept invalid commands' do
      expect {
        testobject.new(
          name: 'test',
          file: '/my/path',
          changes: ['sets /blah/bloo/hah "test"'],
        )
      }.to raise_error(Puppet::Error, %r{Unrecognized command})
    end
    describe 'ins' do
      it 'validates syntax' do
        expect {
          testobject.new(
            name: 'test',
            file: '/my/path',
            changes: ['ins blue befores red'],
          )
        }.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
    describe 'set' do
      it 'validates syntax' do
        expect {
          testobject.new(
            name: 'test',
            file: '/my/path',
            changes: ['set /blah/bloo/hah test'],
          )
        }.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
  end

  describe 'onlyif' do
    it 'requires a fully-qualified xpath' do
      expect {
        testobject.new(
          name: 'test',
          file: '/my/path',
          onlyif: ['get blah/bloo/hah == "test"'],
        )
      }.to raise_error(Puppet::Error, %r{invalid xpath})
    end
    it 'does not accept invalid commands' do
      expect {
        testobject.new(
          name: 'test',
          file: '/my/path',
          onlyif: ['gets /blah/bloo/hah "test"'],
        )
      }.to raise_error(Puppet::Error, %r{Unrecognized command})
    end
    describe 'get' do
      it 'validates syntax' do
        expect {
          testobject.new(
            name: 'test',
            file: '/my/path',
            onlyif: ['get /blah/bloo/hah test'],
          )
        }.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end

    describe 'match' do
      it 'validates syntax' do
        expect {
          testobject.new(
            name: 'test',
            file: '/my/path',
            onlyif: ['match /blah/bloo/hah test'],
          )
        }.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
  end
end
