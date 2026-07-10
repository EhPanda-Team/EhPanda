#include "DartsDict.hpp"
#include "DictGroup.hpp"
#include "Converter.hpp"
#include "MarisaDict.hpp"
#include "MaxMatchSegmentation.hpp"
#include "Conversion.hpp"
#include "ConversionChain.hpp"

#include "header.h"

// MARK: Error

// Records the error code from the most recent failed bridge call. File-scoped rather than
// exported so Swift never sees it as a shared mutable global; it is read via CCLastErrorCode().
static CCErrorCode ccErrorno = CCErrorCodeUnknown;

CCErrorCode CCLastErrorCode(void) {
    return ccErrorno;
}

void* catchOpenCCException(void* (^block)()) {
    try {
        return block();
    } catch (opencc::FileNotFound& ex) {
        ccErrorno = CCErrorCodeFileNotFound;
        return NULL;
    } catch (opencc::InvalidFormat& ex) {
        ccErrorno = CCErrorCodeInvalidFormat;
        return NULL;
    } catch (opencc::InvalidTextDictionary& ex) {
        ccErrorno = CCErrorCodeInvalidTextDictionary;
        return NULL;
    } catch (opencc::InvalidUTF8& ex) {
        ccErrorno = CCErrorCodeInvalidUTF8;
        return NULL;
    } catch (opencc::Exception& ex) {
        ccErrorno = CCErrorCodeUnknown;
        return NULL;
    }
}

// MARK: CCDict

CCDictRef _Nullable CCDictCreateDartsWithPath(const char * _Nonnull path) {
    return catchOpenCCException(^{
        auto dict = opencc::SerializableDict::NewFromFile<opencc::DartsDict>(std::string(path));
        auto dictPtr = new opencc::DictPtr(dict);
        return static_cast<void*>(dictPtr);
    });
}

CCDictRef _Nullable CCDictCreateMarisaWithPath(const char * _Nonnull path) {
    return catchOpenCCException(^{
        auto dict = opencc::SerializableDict::NewFromFile<opencc::MarisaDict>(std::string(path));
        auto dictPtr = new opencc::DictPtr(dict);
        return static_cast<void*>(dictPtr);
    });
}

CCDictRef _Nonnull CCDictCreateWithGroup(CCDictRef _Nonnull * const _Nonnull dictGroup, intptr_t count) {
    std::list<opencc::DictPtr> list;
    for (int i=0; i<count; i++) {
        auto *dictPtr = static_cast<opencc::DictPtr*>(dictGroup[i]);
        list.push_back(*dictPtr);
    }
    auto dict = new opencc::DictGroupPtr(new opencc::DictGroup(list));
    return static_cast<void*>(dict);
}

void CCDictDestroy(CCDictRef _Nonnull dict) {
    auto *dictPtr = static_cast<opencc::DictPtr*>(dict);
    dictPtr->reset();
}

// MARK: CCConverter

CCConverterRef _Nonnull CCConverterCreate(const char * _Nonnull name, CCDictRef _Nonnull segmentation, CCDictRef _Nonnull * const _Nonnull conversionChain, intptr_t chainCount) {
    auto *segmentationPtr = static_cast<opencc::DictPtr*>(segmentation);
    std::list<opencc::ConversionPtr> conversions;
    for (int i=0; i<chainCount; i++) {
        auto *dictPtr = static_cast<opencc::DictPtr*>(conversionChain[i]);
        auto conversion = opencc::ConversionPtr(new opencc::Conversion(*dictPtr));
        conversions.push_back(conversion);
    }
    auto covName = std::string(name);
    auto covSeg = opencc::SegmentationPtr(new opencc::MaxMatchSegmentation(*segmentationPtr));
    auto covChain = opencc::ConversionChainPtr(new opencc::ConversionChain(conversions));
    auto converter = new opencc::Converter(covName, covSeg, covChain);
    return static_cast<void*>(converter);
}

void CCConverterDestroy(CCConverterRef _Nonnull dict) {
    auto converter = static_cast<opencc::Converter*>(dict);
    delete converter;
}

STLString _Nullable CCConverterCreateConvertedStringFromString(CCConverterRef _Nonnull converter, const char * _Nonnull str) {
    return catchOpenCCException(^{
        auto converterPtr = static_cast<opencc::Converter*>(converter);
        auto string = new std::string(converterPtr->Convert(str));
        return static_cast<void*>(string);
    });
}

const char* _Nonnull STLStringGetUTF8String(STLString _Nonnull str) {
    auto string = static_cast<std::string*>(str);
    return string->c_str();
}

void STLStringDestroy(STLString _Nonnull str) {
    auto string = static_cast<std::string*>(str);
    delete string;
}
